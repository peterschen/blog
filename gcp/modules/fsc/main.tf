locals {
  project = var.project
  project_network = var.project_network != null ? var.project_network : var.project
  
  region = var.region
  cluster_zones = var.cluster_zones
  witness_zone = var.witness_zone
  
  domain_name = var.domain_name
  password = var.password
  network = var.network
  subnet = var.subnetwork
  
  machine_type_cluster = var.machine_type_cluster
  machine_type_witness = var.machine_type_witness
  windows_image_witness = var.windows_image_witness
  windows_image_cluster = var.windows_image_cluster

  enable_cluster = var.enable_cluster
  enable_distributednodename = var.enable_distributednodename
  enable_storagespaces = var.enable_storagespaces
  
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
  project = data.google_project.network.project_id
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnet.id
  name = "fsc-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "cluster" {
  count = local.enable_distributednodename ? 0 : 1
  project = data.google_project.network.project_id
  region = local.region
  name = "cluster"
  address_type = "INTERNAL"
  purpose = "SHARED_LOADBALANCER_VIP"
  subnetwork = data.google_compute_subnetwork.subnet.id
}

resource "google_compute_address" "fsc" {
  project = data.google_project.network.project_id
  region = local.region
  name = "fsc"
  address_type = "INTERNAL"
  purpose = "SHARED_LOADBALANCER_VIP"
  subnetwork = data.google_compute_subnetwork.subnet.id
}

resource "google_compute_address" "witness" {
  project = data.google_project.network.project_id
  region = local.region
  name = "witness"
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
  zone = local.cluster_zones[count.index]
  name = "fsc-${count.index}"
  machine_type = local.machine_type_cluster

  tags = ["cluster", "fsc", "smb", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image_cluster
      type = "pd-ssd"
    }
  }

  dynamic "scratch_disk" {
    for_each = range(local.cache_disk_count)
    content {
      interface = local.cache_disk_interface
    }
  }

  dynamic "attached_disk" {
    for_each = local.capacity_disk_count == 0 ? [] : range(count.index, local.capacity_disk_count * local.node_count, local.node_count)
    content {
      source = google_compute_disk.capacity[attached_disk.value].id
      device_name = "fsc-${count.index}-capacity-${floor((attached_disk.value - count.index) / local.node_count)}"
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
          enableDistributedNodeName = local.enable_distributednodename,
          enableStorageSpaces = local.enable_storagespaces,
          ipCluster = local.enable_distributednodename ? null : google_compute_address.cluster[0].address,
          ipFsc = google_compute_address.fsc.address,
          cacheDiskInterface = local.cache_disk_interface,
          witnessName = google_compute_instance.witness.name,
          modulesDsc = [
            {
              Name = "FailoverClusterDsc",
              Version = "2.1.0"
            }
          ]
        })
      })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [
    module.apis
  ]
}

resource "google_compute_instance" "witness" {
  project = data.google_project.default.project_id
  zone = local.witness_zone
  name = "witness"
  machine_type = local.machine_type_witness

  tags = ["smb", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image_witness
      type = "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.network.id
    subnetwork = data.google_compute_subnetwork.subnet.id
    network_ip = google_compute_address.witness.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "witness", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/witness.ps1"),
          domainName = local.domain_name,
          modulesDsc = []
        })
      })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [
    module.apis
  ]
}

resource "google_compute_disk" "capacity" {
  count = local.node_count * local.capacity_disk_count
  project = data.google_project.default.project_id
  zone = local.cluster_zones[floor(count.index / local.capacity_disk_count)]
  name = "capacity-${count.index}"
  type = local.capacity_disk_type
  size = local.capacity_disk_size
}

resource "google_compute_instance_group" "cluster" {
  count = length(google_compute_instance.fsc)
  project = data.google_project.default.project_id
  zone = local.cluster_zones[count.index]
  name = "cluster-${count.index}"
  
  network = data.google_compute_network.network.self_link
  
  instances = [
    google_compute_instance.fsc[count.index].self_link
  ]
}

resource "google_compute_health_check" "cluster" {
  count = local.enable_distributednodename ? 0 : 1
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
    request = google_compute_address.cluster[count.index].address
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

resource "google_compute_region_backend_service" "cluster_tcp" {
  count = local.enable_distributednodename ? 0 :1
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster-tcp"
  protocol = "TCP"
  health_checks = [
    google_compute_health_check.cluster[0].id
  ]

  dynamic "backend" {
    for_each = google_compute_instance_group.cluster
    content {
      group = backend.value.id
    }
  }

  depends_on = [
    google_compute_instance_group.cluster
  ]
}

resource "google_compute_region_backend_service" "cluster_udp" {
  count = local.enable_distributednodename ? 0 :1
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster-udp"
  protocol = "UDP"
  health_checks = [
    google_compute_health_check.cluster[0].id
  ]

  dynamic "backend" {
    for_each = google_compute_instance_group.cluster
    content {
      group = backend.value.id
    }
  }

  depends_on = [
    google_compute_instance_group.cluster
  ]
}

resource "google_compute_region_backend_service" "fsc_tcp" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc-tcp"
  protocol = "TCP"
  health_checks = [
    google_compute_health_check.fsc.id
  ]

  dynamic "backend" {
    for_each = google_compute_instance_group.cluster
    content {
      group = backend.value.id
    }
  }

  depends_on = [
    google_compute_instance_group.cluster
  ]
}

resource "google_compute_region_backend_service" "fsc_udp" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc-udp"
  protocol = "UDP"
  health_checks = [
    google_compute_health_check.fsc.id
  ]

  dynamic "backend" {
    for_each = google_compute_instance_group.cluster
    content {
      group = backend.value.id
    }
  }

  depends_on = [
    google_compute_instance_group.cluster
  ]
}

resource "google_compute_forwarding_rule" "cluster_tcp" {
  count = local.enable_distributednodename ? 0 : 1
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster-tcp"
  ip_protocol = "TCP"
  ip_address = google_compute_address.cluster[count.index].address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnet.id
  backend_service = google_compute_region_backend_service.cluster_tcp[count.index].id
}

resource "google_compute_forwarding_rule" "cluster_udp" {
  count = local.enable_distributednodename ? 0 : 1
  project = data.google_project.default.project_id
  region = local.region
  name = "cluster-udp"
  ip_protocol = "UDP"
  ip_address = google_compute_address.cluster[count.index].address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnet.id
  backend_service = google_compute_region_backend_service.cluster_udp[count.index].id
}

resource "google_compute_forwarding_rule" "fsc_tcp" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc-tcp"
  ip_protocol = "TCP"
  ip_address = google_compute_address.fsc.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnet.id
  backend_service = google_compute_region_backend_service.fsc_tcp.id
}

resource "google_compute_forwarding_rule" "fsc_udp" {
  project = data.google_project.default.project_id
  region = local.region
  name = "fsc-udp"
  ip_protocol = "UDP"
  ip_address = google_compute_address.fsc.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnet.id
  backend_service = google_compute_region_backend_service.fsc_udp.id
}
