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
  count-nodes = var.node-count
  count-disks = 1
  size-disks = 1000
}

module "gce-default-scopes" {
  source = "../../modules/gce-default-scopes"
}

module "apis" {
  source = "../../modules/apis"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

module "sysprep" {
  source = "../../modules/sysprep"
}

module "cloud-nat" {
  source = "../../modules/cloud-nat"
  region = local.region
  network = google_compute_network.network.name
  depends_on = [google_compute_network.network]
}

module "firewall-iap" {
  source = "../../modules/firewall-iap"
  network = google_compute_network.network.name
  enable-ssh = false
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

resource "google_compute_instance" "perf-nodes" {
  count = local.count-nodes
  zone = local.zone
  name = "perf-node-${count.index}"
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
    type = "perf-node"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
        nameHost = "perf-node-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/perf-node.ps1"),
          scriptBenchmark = filebase64("${path.module}/benchmark.ps1"),
          scriptConversion = filebase64("${path.module}/conversion.ps1")
        })
      })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}

resource "google_compute_disk" "perf-node-ssd" {
  count = local.count-nodes * local.count-disks
  zone = google_compute_instance.perf-nodes[floor(count.index / local.count-disks)].zone
  name = "perf-node-ssd-${format("%02g", count.index)}"
  type = "pd-ssd"
  size = local.size-disks
}

resource "google_compute_attached_disk" "perf-node-ssd" {
  count = local.count-nodes * local.count-disks
  disk = google_compute_disk.perf-node-ssd[count.index].self_link
  instance = google_compute_instance.perf-nodes[floor(count.index / local.count-disks)].self_link
  device_name = "pd-${count.index}"
}
