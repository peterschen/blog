provider "google" {
  project = var.project
}

locals {
  project = var.project
  region = var.region
  zone = var.zone
  name-domain = var.domain-name
  password = var.password
  network = var.network
  subnetwork = var.subnetwork
  machine-type = var.machine-type
  node-count = 2
}

data "google_compute_network" "network" {
  project = local.project
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  project = local.project
  region = local.region
  name = local.subnetwork
}

module "apis" {
  source = "github.com/peterschen/blog//gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
}

module "gce-default-scopes" {
  source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
}

module "sysprep" {
  source = "github.com/peterschen/blog//gcp/modules/sysprep"
}

module "firewall-mssql" {
  source = "github.com/peterschen/blog//gcp/modules/firewall-mssql"
  name = "allow-mssql"
  network = data.google_compute_network.network
  cidr-ranges = [data.google_compute_subnetwork.subnetwork.ip_cidr_range]
}

resource "google_compute_address" "sql" {
  count = local.node-count
  project = local.project
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  name = "sql-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "sql-cl" {
  project = local.project
  region = local.region
  name = "sql-cl"
  address_type = "INTERNAL"
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
}

resource "google_compute_instance" "sql" {
  count = local.node-count
  project = local.project
  zone = local.zone
  name = "sql-${count.index}"
  machine_type = local.machine-type

  tags = ["mssql", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-web-2019-win-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
    network_ip = google_compute_address.sql[count.index].address
  }

  metadata = {
    type = "sql"
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
        nameHost = "sql-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          domainName = local.name-domain,
          zone = local.zone
          networkRange = data.google_compute_subnetwork.subnetwork.ip_cidr_range,
          isFirst = (count.index == 0),
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/sql.ps1"),
          modulesDsc = [
            { 
              Name = "SqlServerDsc",
              Version = "13.5.0"
              Uri = "https://github.com/dsccommunity/SqlServerDsc/archive/v13.5.0.zip"
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

  depends_on = [module.apis]
}

resource "google_compute_instance_group" "sql" {
  count = local.node-count
  project = local.project
  zone = local.zone
  name = "sql-${count.index}"
  instances = [google_compute_instance.sql[count.index].self_link]
  network = data.google_compute_network.network.self_link
}

resource "google_compute_health_check" "sql" {
  project = local.project
  name = "sql"
  timeout_sec = 1
  check_interval_sec = 2

  tcp_health_check {
    port = 59998
    request = google_compute_address.sql-cl.address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "sql" {
  project = local.project
  region = local.region
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
  provider = google-beta
  project = local.project
  region = local.region
  name = "sql"
  ip_address = google_compute_address.sql-cl.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = data.google_compute_network.network.self_link
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  backend_service = google_compute_region_backend_service.sql.self_link
}
