locals {
  project = var.project
  project_network = var.project_network != null ? var.project_network : var.project
  
  region = var.region
  zones = var.zones
  
  domain_name = var.domain_name
  password = var.password
  network = var.network
  subnet = var.subnetwork
  
  machine_type = var.machine_type
  windows_image = var.windows_image

  enable_cluster = var.enable_cluster
  node_count = var.node_count

  cache_disk_count = var.cache_disk_count
  cache_disk_interface = var.cache_disk_interface
  capacity_disk_count = var.capacity_disk_count
  capacity_disk_type = var.capacity_disk_type
  capacity_disk_size = var.capacity_disk_size
}

data "google_project" "default" {
  project_id = local.project
}

data "google_project" "network" {
  project_id = local.project_network
}

data "google_compute_network" "network" {
  project = data.google_project.network.project_id
  name = local.network
}

data "google_compute_subnetwork" "subnet" {
  project = data.google_project.network.project_id
  region = local.region
  name = local.subnet
}

module "apis" {
  source = "../apis"
  project = data.google_project.default.project_id
  
  apis = [
    "compute.googleapis.com"
  ]
}

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

module "firewall_smb" {
  project = data.google_project.network.project_id
  source = "../firewall_smb"
  
  network = data.google_compute_network.network.name

  cidr_ranges = [
    data.google_compute_subnetwork.subnet.ip_cidr_range
  ]
}

resource "google_compute_address" "node" {
  count = local.node_count
  project = data.google_project.default.project_id
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnet.id
  name = "fsc-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "cluster" {
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster"
  address_type = "INTERNAL"
  subnetwork = data.google_compute_subnetwork.subnet.id
}

resource "google_compute_address" "fsc" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc"
  address_type = "INTERNAL"
  subnetwork = data.google_compute_subnetwork.subnet.id
}

resource "google_compute_firewall" "allow_healthcheck_cluster_gcp" {
  project = data.google_project.network.project_id
  name = "allow-healthcheck-cluster-gcp"
  network = data.google_compute_network.network.id
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = ["cluster"]
}

resource "google_compute_instance" "fsc" {
  count = local.node_count
  project = data.google_project.default.project_id
  zone = local.zones[count.index]
  name = "fsc-${count.index}"
  machine_type = local.machine_type

  tags = ["cluster", "fsc", "smb", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = "pd-ssd"
    }
  }

  dynamic "scratch_disk" {
    for_each = range(local.cache_disk_count)
    content {
      interface = local.cache_disk_interface
    }
  }

  network_interface {
    network = data.google_compute_network.network.id
    subnetwork = data.google_compute_subnetwork.subnet.id
    network_ip = google_compute_address.node[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "fsc-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/fsc.ps1"),
          domainName = local.domain_name,
          isFirst = (count.index == 0),
          nodePrefix = "fsc",
          nodeCount = local.node_count,
          enableCluster = local.enable_cluster,
          ipCluster = google_compute_address.cluster.address,
          ipFsc = google_compute_address.fsc.address,
          cacheDiskInterface = local.cache_disk_interface,
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
    ignore_changes = [
      attached_disk
    ]
  }

  allow_stopping_for_update = true

  depends_on = [
    module.apis
  ]
}

resource "google_compute_disk" "capacity" {
  count = length(google_compute_instance.fsc) * local.capacity_disk_count
  project = data.google_project.default.project_id
  zone = google_compute_instance.fsc[floor(count.index / local.capacity_disk_count)].zone
  name = "fsc-${floor(count.index / local.capacity_disk_count)}-capacity-${count.index - (local.capacity_disk_count * floor(count.index / local.capacity_disk_count))}"
  type = local.capacity_disk_type
  size = local.capacity_disk_size
}

resource "google_compute_attached_disk" "capacity" {
  count = length(google_compute_instance.fsc) * local.capacity_disk_count
  project = data.google_project.default.project_id
  disk = google_compute_disk.capacity[count.index].id
  instance = google_compute_instance.fsc[floor(count.index / local.capacity_disk_count)].id
  device_name = "fsc-${floor(count.index / local.capacity_disk_count)}-capacity-${count.index - (local.capacity_disk_count * floor(count.index / local.capacity_disk_count))}"
}

resource "google_compute_instance_group" "cluster" {
  count = length(google_compute_instance.fsc)
  project = data.google_project.default.project_id
  zone = local.zones[count.index]
  name = "cluster-${count.index}"
  
  network = data.google_compute_network.network.id
  
  instances = [
    google_compute_instance.fsc[count.index].id
  ]
}

resource "google_compute_health_check" "cluster" {
  project = data.google_project.default.project_id
  name = "cluster"
  timeout_sec = 2
  check_interval_sec = 2
  healthy_threshold = 1
  unhealthy_threshold = 1

  log_config {
    enable = true
  }

  tcp_health_check {
    port = 59998
    request = google_compute_address.cluster.address
    response = "1"
  }
}

resource "google_compute_health_check" "fsc" {
  project = data.google_project.default.project_id
  name = "fsc"
  timeout_sec = 2
  check_interval_sec = 2
  healthy_threshold = 1
  unhealthy_threshold = 1

  log_config {
    enable = true
  }

  tcp_health_check {
    port = 59998
    request = google_compute_address.fsc.address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "cluster" {
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster"
  health_checks = [
    google_compute_health_check.cluster.id
  ]

  dynamic "backend" {
    for_each = google_compute_instance_group.cluster
    content {
      group = backend.value.id
    }
  }
}

resource "google_compute_region_backend_service" "fsc" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc"
  health_checks = [
    google_compute_health_check.fsc.id
  ]

  dynamic "backend" {
    for_each = google_compute_instance_group.cluster
    content {
      group = backend.value.id
    }
  }
}

resource "google_compute_forwarding_rule" "cluster" {
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster"
  ip_address = google_compute_address.cluster.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnet.id
  backend_service = google_compute_region_backend_service.cluster.id
}

resource "google_compute_forwarding_rule" "fsc" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc"
  ip_address = google_compute_address.fsc.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnet.id
  backend_service = google_compute_region_backend_service.fsc.id
}
