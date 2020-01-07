provider "google" {
  version = "~> 3.1"
  project = "${var.project}"
}

provider "google-beta" {
  version = "~> 3.1"
  project = "${var.project}"
}

locals {
  name-sample = "sofs-on-gcp"
  count-instances = 3
  count-disks = 4
  size-disks = 100
}

module "ad-on-gcp" {
  source = "github.com/peterschen/blog/gcp/samples/ad-on-gcp"
  project = var.project
  regions = var.regions
  zones = var.zones
  name-domain = var.name-domain
  password = var.password
}

resource "google_compute_firewall" "allow-lbhealthcheck-gcp" {
  name    = "allow-lbhealthcheck-gcp"
  network = module.ad-on-gcp.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_compute_address" "sofs-cl" {
  region = var.regions[0]
  name = "sofs-cl"
  address_type = "INTERNAL"
  subnetwork = module.ad-on-gcp.subnets[0]
  depends_on = [module.ad-on-gcp]
}

resource "google_compute_instance" "sofs" {
  count = local.count-instances
  zone = "${var.regions[0]}-${var.zones[0][count.index]}"
  name = "sofs-${count.index}"
  machine_type = "n1-standard-2"

  tags = ["rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = module.ad-on-gcp.network
    subnetwork = module.ad-on-gcp.subnets[0]
  }

  metadata = {
    sample = local.name-sample
    type = "sofs"
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile("${module.ad-on-gcp.path-module}/specialize.ps1", { 
        nameHost = "sofs-${count.index}", 
        nameConfiguration = "sofs",
        uriMeta = var.uri-meta,
        uriConfigurations = var.uri-configurations,
        password = var.password,
        parametersConfiguration = jsonencode({
          domainName = var.name-domain,
          nodePrefix = "sofs"
          nodeCount = local.count-instances
          ipCluster = google_compute_address.sofs-cl.address,
          isFirst = (count.index == 0)
        })
      })
  }
}

resource "google_compute_disk" "sofs-disks" {
  count = local.count-instances * local.count-disks
  zone = google_compute_instance.sofs[floor(count.index / local.count-disks)].zone
  name = "sofs-disk-${count.index}"
  type = "pd-ssd"
  size = local.size-disks
}

resource "google_compute_attached_disk" "sofs-disks" {
  count = local.count-instances * local.count-disks
  disk = google_compute_disk.sofs-disks[count.index].self_link
  instance = google_compute_instance.sofs[floor(count.index / local.count-disks)].self_link
}

resource "google_compute_instance_group" "sofs" {
  count = local.count-instances
  zone = "${var.regions[0]}-${var.zones[0][count.index]}"
  name = "sofs-${count.index}"
  instances = [google_compute_instance.sofs[count.index].self_link]
  network = module.ad-on-gcp.network
}

resource "google_compute_health_check" "sofs" {
  name = "sofs"
  timeout_sec = 1
  check_interval_sec = 2

  tcp_health_check {
    port = 59998
    request = google_compute_address.sofs-cl.address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "sofs" {
  region = var.regions[0]
  name = "sofs"
  health_checks = [google_compute_health_check.sofs.self_link]

  dynamic "backend" {
    for_each = google_compute_instance_group.sofs
    content {
      group = backend.value.self_link
    }
  }
}

resource "google_compute_forwarding_rule" "sofs" {
  provider = "google-beta"
  region = var.regions[0]
  name = "sofs"
  ip_address = google_compute_address.sofs-cl.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = module.ad-on-gcp.network
  subnetwork = module.ad-on-gcp.subnets[0]
  backend_service = google_compute_region_backend_service.sofs.self_link
}
