terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
  project = var.project
}

locals {
  region = var.region
  zone = var.zone
  name-sample = "win-perf"
  password = var.password
  network-range = "10.0.0.0/16"
  machine-type = var.machine-type
  count-disks = 1
  size-disks = 1000
}

module "gce_scopes" {
  source = "../../modules/gce_scopes"
}

module "apis" {
  source = "../../modules/apis"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

module "sysprep" {
  source = "../../modules/sysprep"
}

module "nat" {
  source = "../../modules/nat"
  region = local.region
  network = google_compute_network.network.name
  depends_on = [google_compute_network.network]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  network = google_compute_network.network.name
  enable_ssh = false
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  region = local.region
  name = local.region
  ip_cidr_range = local.network-range
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [local.network-range]
}

resource "google_compute_instance" "runner" {
  zone = local.zone
  name = "runner"
  machine_type = local.machine-type

  tags = ["rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnetwork.self_link
  }

  metadata = {
    type = "runner"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
        nameHost = "runner", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/dsc/runner.ps1"),
          scriptBenchmark = filebase64("${path.module}/benchmark.ps1"),
          scriptConversion = filebase64("${path.module}/conversion.ps1")
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

resource "google_compute_instance" "sql" {
  zone = local.zone
  name = "sql"
  machine_type = local.machine-type

  tags = ["rdp"]

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-ent-2019-win-2019"
      type = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnetwork.self_link
  }

  metadata = {
    type = "sql"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
        nameHost = "sql", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/dsc/sql.ps1"),
          modulesDsc = [
            {
              Name = "StorageDsc",
              Version = "5.0.1"
              Uri = "https://github.com/dsccommunity/StorageDsc/archive/v5.0.1.zip"
            },
            {
              Name = "SqlServerDsc",
              Version = "15.1.1"
              Uri = "https://github.com/dsccommunity/SqlServerDsc/archive/v15.1.1.zip"
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

resource "google_compute_disk" "runner-ssd" {
  count = local.count-disks
  zone = google_compute_instance.runner.zone
  name = "runner-ssd-${format("%02g", count.index)}"
  type = "pd-ssd"
  size = local.size-disks
}

resource "google_compute_attached_disk" "runner-ssd" {
  count = local.count-disks
  disk = google_compute_disk.runner-ssd[count.index].self_link
  instance = google_compute_instance.runner.self_link
  device_name = "pd-${count.index}"
}

resource "google_compute_disk" "sql-ssd" {
  count = local.count-disks
  zone = google_compute_instance.sql.zone
  name = "sql-ssd-${format("%02g", count.index)}"
  type = "pd-ssd"
  size = local.size-disks
}

resource "google_compute_attached_disk" "sql-ssd" {
  count = local.count-disks
  disk = google_compute_disk.sql-ssd[count.index].self_link
  instance = google_compute_instance.sql.self_link
  device_name = "pd-${count.index}"
}
