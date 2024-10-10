locals {
  project = var.project
  project_network = var.project_network == null ? var.project : var.project_network

  region = var.region
  zones = var.zones

  domain_name = var.domain_name
  password = var.password
  
  network = var.network
  subnetwork = var.subnetwork

  machine_type = var.machine_type
  windows_image = var.windows_image

  use_developer_edition = var.use_developer_edition
  enable_cluster = var.enable_alwayson ? true : var.enable_cluster
  enable_alwayson = var.enable_alwayson
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

data "google_compute_subnetwork" "subnetwork" {
  project = data.google_project.network.project_id
  region = local.region
  name = local.subnetwork
}

module "apis" {
  source = "../apis"
  project = data.google_project.default.project_id
  apis = [
    "compute.googleapis.com",
    "dns.googleapis.com"
  ]
}

module "firewall_mssql" {
  source = "../firewall_mssql"
  project = local.project
  name = "allow-mssql"
  network = data.google_compute_network.network
  cidr_ranges = [data.google_compute_subnetwork.subnetwork.ip_cidr_range]
}

resource "google_compute_address" "sql" {
  count = length(local.zones)
  project = data.google_project.network.project_id
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.id
  name = "sql-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "sql_cl" {
  count = local.enable_cluster ? 1 : 0
  region = local.region
  project = local.project
  name = "sql-cl"
  address_type = "INTERNAL"
  purpose = "SHARED_LOADBALANCER_VIP"
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
}

resource "google_compute_firewall" "allow_healthcheck_mssql_gcp" {
  count = local.enable_cluster ? 1 : 0
  name = "allow-healthcheck-mssql-gcp"
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

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

resource "google_compute_instance" "sql" {
  count = length(local.zones)
  project = local.project
  zone = local.zones[count.index]
  name = "sql-${count.index}"

  machine_type = local.machine_type

  tags = ["mssql", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = strcontains(local.machine_type, "n4") ? "hyperdisk-balanced" : "pd-ssd"
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
          zone = local.zones[count.index]
          networkRange = data.google_compute_subnetwork.subnetwork.ip_cidr_range,
          isFirst = (count.index == 0),
          nodePrefix = "sql",
          nodeCount = length(local.zones),
          ipCluster = local.enable_cluster ? google_compute_address.sql_cl[0].address : null,
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/sql.ps1"),
          useDeveloperEdition = local.use_developer_edition,
          enableCluster = local.enable_cluster,
          enableAlwaysOn = local.enable_alwayson,
          modulesDsc = [
            {
              Name = "FailOverClusterDsc",
              Version = "2.1.0"
            },
            { 
              Name = "SqlServerDsc",
              Version = "16.0.0"
            },
            { 
              Name = "StorageDsc",
              Version = "6.0.1"
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
  count = local.enable_cluster ? length(local.zones) : 0
  project = local.project
  zone = local.zones[count.index]
  name = "sql-${count.index}"
  instances = [google_compute_instance.sql[count.index].self_link]
  network = data.google_compute_network.network.self_link
}

resource "google_compute_health_check" "sql" {
  count = local.enable_cluster ? 1 : 0
  name = "sql"
  project = local.project
  timeout_sec = 1
  check_interval_sec = 2

  tcp_health_check {
    port = 59998
    request = google_compute_address.sql_cl[count.index].address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "sql" {
  count = local.enable_cluster ? 1 : 0
  region = local.region
  project = local.project
  name = "sql"
  health_checks = [
    google_compute_health_check.sql[count.index].id
  ]
  protocol = "UNSPECIFIED"

  dynamic "backend" {
    for_each = google_compute_instance_group.sql
    content {
      group = backend.value.id
    }
  }
}

resource "google_compute_forwarding_rule" "sql" {
  count = local.enable_cluster ? 1 : 0
  region = local.region
  project = local.project
  name = "sql"
  ip_address = google_compute_address.sql_cl[count.index].address
  load_balancing_scheme = "INTERNAL"
  ip_protocol = "L3_DEFAULT"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.id
  subnetwork = data.google_compute_subnetwork.subnetwork.id
  backend_service = google_compute_region_backend_service.sql[count.index].id
}
