provider "google" {
  version = "~> 3.1"
  project = var.project
}

provider "google-beta" {
  version = "~> 3.1"
  project = var.project
}

locals {
  project = var.project
  regions = var.regions
  zones = var.zones
  name-sample = "sofs-on-gcp"
  name-domain = var.name-domain
  uri-meta = var.uri-meta
  password = var.password
  provision-cluster = var.provision-cluster
  provision-hdd = var.provision-hdd
  count-nodes = 3
  count-disks = 4
  size-disks = 100
}

module "gce-default-scopes" {
  source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
}

module "ad-on-gcp" {
  source = "github.com/peterschen/blog//gcp/samples/ad-on-gcp?ref=fix-91"
  project = local.project
  regions = local.regions
  zones = local.zones
  name-domain = local.name-domain
  password = local.password
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
  region = local.regions[0]
  name = "sofs-cl"
  address_type = "INTERNAL"
  subnetwork = module.ad-on-gcp.subnets[0]
  depends_on = [module.ad-on-gcp]
}

resource "google_compute_instance" "sofs" {
  count = local.count-nodes
  zone = "${local.regions[0]}-${local.zones[0][count.index]}"
  name = "sofs-${count.index}"
  machine_type = "n1-standard-2"

  tags = ["rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
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
    sysprep-specialize-script-ps1 = templatefile(module.ad-on-gcp.path-specialize, { 
        nameHost = "sofs-${count.index}", 
        uriMeta = local.uri-meta,
        password = local.password,
        parametersConfiguration = jsonencode({
          domainName = var.name-domain,
          provisionCluster = local.provision-cluster
          nodePrefix = "sofs",
          nodeCount = local.count-nodes,
          ipCluster = google_compute_address.sofs-cl.address,
          isFirst = (count.index == 0),
          inlineConfiguration = filebase64("${path.module}/sofs.ps1"),
          modulesDsc = [
            {
              Name = "xFailOverCluster",
              Version = "1.14.1"
              Uri = "https://github.com/dsccommunity/xFailOverCluster/archive/v1.14.1.zip"
            }
          ]
        })
      })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_disk" "sofs-hdd" {
  count = local.provision-hdd ? local.count-nodes * local.count-disks : 0
  zone = google_compute_instance.sofs[floor(count.index / local.count-disks)].zone
  name = "sofs-hdd-${count.index}"
  type = "pd-standard"
  size = local.size-disks
}

resource "google_compute_attached_disk" "sofs-hdd" {
  count = local.provision-hdd ? local.count-nodes * local.count-disks : 0
  disk = google_compute_disk.sofs-hdd[count.index].self_link
  instance = google_compute_instance.sofs[floor(count.index / local.count-disks)].self_link
}

resource "google_compute_disk" "sofs-ssd" {
  count = local.count-nodes * local.count-disks
  zone = google_compute_instance.sofs[floor(count.index / local.count-disks)].zone
  name = "sofs-ssd-${count.index}"
  type = "pd-ssd"
  size = local.size-disks
}

resource "google_compute_attached_disk" "sofs-ssd" {
  count = local.count-nodes * local.count-disks
  disk = google_compute_disk.sofs-ssd[count.index].self_link
  instance = google_compute_instance.sofs[floor(count.index / local.count-disks)].self_link
}

resource "google_compute_instance_group" "sofs" {
  count = local.count-nodes
  zone = "${local.regions[0]}-${local.zones[0][count.index]}"
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
  region = local.regions[0]
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
  provider = google-beta
  region = local.regions[0]
  name = "sofs"
  ip_address = google_compute_address.sofs-cl.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = module.ad-on-gcp.network
  subnetwork = module.ad-on-gcp.subnets[0]
  backend_service = google_compute_region_backend_service.sofs.self_link
}
