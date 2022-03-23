locals {
  project = var.project
  project_network = var.project_network
  region = var.region
  zone = var.zone
  domain_name = var.domain_name
  password = var.password
  network = var.network
  subnetwork = var.subnetwork
  machine_type = var.machine_type

  windows_image = var.windows_image

  enable_cluster = var.enable_cluster
  enable_hdd = var.enable_hdd
  count_nodes = var.node_count
  ssd_count = var.ssd_count
  hdd_count = var.hdd_count
  ssd_size = var.ssd_size
  hdd_size = var.hdd_size
}

data "google_compute_network" "network" {
  project = var.project_network
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  project = var.project_network
  region = local.region
  name = local.subnetwork
}

module "apis" {
  source = "../apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

module "firewall_sofs" {
  project = local.project
  source = "../firewall_sofs"
  name = "allow-sofs"
  network = data.google_compute_network.network
  cidr_ranges = [data.google_compute_subnetwork.subnetwork.ip_cidr_range]
}

resource "google_compute_address" "sofs" {
  count = local.count_nodes
  project = local.project
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  name = "sofs-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "sofs_cl" {
  region = local.region
  project = local.project
  name = "sofs-cl"
  address_type = "INTERNAL"
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
}

resource "google_compute_firewall" "allow_healthcheck_sofs_gcp" {
  project = local.project_network
  name = "allow-healthcheck-sofs-gcp"
  network = data.google_compute_network.network.self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = ["sofs"]
}

resource "google_compute_instance" "sofs" {
  count = local.count_nodes
  project = local.project
  zone = local.zone
  name = "sofs-${count.index}"
  machine_type = local.machine_type

  tags = ["sofs", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
    network_ip = google_compute_address.sofs[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    type = "sofs"
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "sofs-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/sofs.ps1"),
          domainName = local.domain_name,
          isFirst = (count.index == 0),
          nodePrefix = "sofs",
          nodeCount = local.count_nodes,
          enableCluster = local.enable_cluster,
          ipCluster = google_compute_address.sofs_cl.address,
          modulesDsc = [
            {
              Name = "xFailOverCluster",
              Version = "1.16.0"
            }
          ]
        })
      })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}

resource "google_compute_disk" "sofs_hdd" {
  count = local.enable_hdd ? local.count_nodes * local.hdd_count : 0
  project = local.project
  zone = google_compute_instance.sofs[floor(count.index / local.hdd_count)].zone
  name = "sofs-hdd-${count.index}"
  type = "pd-standard"
  size = local.hdd_size
}

resource "google_compute_attached_disk" "sofs_hdd" {
  count = local.enable_hdd ? local.count_nodes * local.hdd_count : 0
  project = local.project
  disk = google_compute_disk.sofs_hdd[count.index].self_link
  instance = google_compute_instance.sofs[floor(count.index / local.hdd_count)].self_link
}

resource "google_compute_disk" "sofs_ssd" {
  count = local.count_nodes * local.ssd_count
  project = local.project
  zone = google_compute_instance.sofs[floor(count.index / local.ssd_count)].zone
  name = "sofs-ssd-${count.index}"
  type = "pd-ssd"
  size = local.ssd_size
}

resource "google_compute_attached_disk" "sofs_ssd" {
  count = local.count_nodes * local.ssd_count
  project = local.project
  disk = google_compute_disk.sofs_ssd[count.index].self_link
  instance = google_compute_instance.sofs[floor(count.index / local.ssd_count)].self_link
}

resource "google_compute_instance_group" "sofs" {
  count = local.count_nodes
  project = local.project
  zone = local.zone
  name = "sofs-${count.index}"
  instances = [google_compute_instance.sofs[count.index].self_link]
  network = data.google_compute_network.network.self_link
}

resource "google_compute_health_check" "sofs" {
  name = "sofs"
  project = local.project
  timeout_sec = 1
  check_interval_sec = 2

  tcp_health_check {
    port = 59998
    request = google_compute_address.sofs_cl.address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "sofs" {
  region = local.region
  project = local.project
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
  region = local.region
  project = local.project
  name = "sofs"
  ip_address = google_compute_address.sofs_cl.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.self_link
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  backend_service = google_compute_region_backend_service.sofs.self_link
}
