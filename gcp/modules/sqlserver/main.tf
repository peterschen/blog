locals {
  project = var.project
  projectNetwork = var.projectNetwork
  region = var.region
  zone = var.zone
  domain_name = var.domain_name
  password = var.password
  network = var.network
  subnetwork = var.subnetwork
  machine_type = var.machine_type

  windows_image = var.windows_image

  enable_aag = var.enable_aag
  node_count = 2
}

data "google_compute_network" "network" {
  project = local.project_network
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  project = local.project_network
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

module "firewall_mssql" {
  source = "../firewall_mssql"
  project = local.project
  name = "allow-mssql"
  network = data.google_compute_network.network
  cidr_ranges = [data.google_compute_subnetwork.subnetwork.ip_cidr_range]
}

resource "google_compute_address" "sql" {
  count = local.node-count
  project = local.project
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  name = "sql-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "sql_cl" {
  region = local.region
  project = local.project
  name = "sql-cl"
  address_type = "INTERNAL"
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
}

resource "google_compute_firewall" "allow_mssqlhealthcheck_gcp" {
  name = "allow-mssqlhealthcheck-gcp"
  project = local.project
  network = data.google_compute_network.network.self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = ["mssql"]
}

resource "google_compute_instance" "sql" {
  count = local.node_count
  project = local.project
  zone = local.zone
  name = "sql-${count.index}"
  machine_type = local.machine_type

  tags = ["mssql", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
    network_ip = google_compute_address.sql[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    type = "sql"
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "sql-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          domainName = local.domain_name,
          zone = local.zone
          networkRange = data.google_compute_subnetwork.subnetwork.ip_cidr_range,
          isFirst = (count.index == 0),
          nodePrefix = "sql",
          nodeCount = local.node_count,
          ipCluster = google_compute_address.sql_cl.address,
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/sql.ps1"),
          enableAag = local.enable_aag,
          modulesDsc = [
            {
              Name = "xFailOverCluster",
              Version = "1.16.0"
            },
            { 
              Name = "SqlServerDsc",
              Version = "15.1.1"
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

resource "google_compute_instance_group" "sql" {
  count = local.node_count
  project = local.project
  zone = local.zone
  name = "sql-${count.index}"
  instances = [google_compute_instance.sql[count.index].self_link]
  network = data.google_compute_network.network.self_link
}

resource "google_compute_health_check" "sql" {
  name = "sql"
  project = local.project
  timeout_sec = 1
  check_interval_sec = 2

  tcp_health_check {
    port = 59998
    request = google_compute_address.sql_cl.address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "sql" {
  region = local.region
  project = local.project
  name = "sql"
  health_checks = [google_compute_health_check.sql.self_link]

  dynamic "backend" {
    for_each = google_compute_instance_group.sql
    content {
      group = backend.value.self_link
    }
  }
}

resource "google_compute_forwarding_rule" "sql" {
  region = local.region
  project = local.project
  name = "sql"
  ip_address = google_compute_address.sql_cl.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.self_link
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  backend_service = google_compute_region_backend_service.sql.self_link
}
