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
  nameNetwork = var.networkName
  nameDomain = var.domainName
  nameServers = [
    "sr-source",
    "sr-target",
    "sr-replicator"
  ]
  nameConfigs = [
    "sr-target",
    "sr-target",
    "sr-replicator"
  ]
  machineType = var.machineType
  password = var.password
  sizeDiskData = 10
  sizeDiskLog = 10
}

module "gce_scopes" {
  source = "../../modules/gce_scopes"
}

module "sysprep" {
  source = "../../modules/sysprep"
}

data "google_compute_network" "network" {
  name = local.nameNetwork
}

data "google_compute_subnetwork" "subnetwork" {
  region = local.region
  name = local.region
}

resource "google_compute_instance" "vm" {
  count = length(local.nameServers)
  zone = local.zone
  name = local.nameServers[count.index]
  machine_type = local.machineType

  tags = ["storage-replica", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
      nameHost = local.nameServers[count.index], 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path-meta),
        inlineConfiguration = filebase64("${path.module}/dsc/${local.nameConfigs[count.index]}.ps1"),
        nameDomain = local.nameDomain,
        nameTarget = local.nameServers[length(local.nameServers) - 1],
        sizeDiskData = local.sizeDiskData,
        sizeDiskLog = local.sizeDiskLog
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
}

resource "google_compute_disk" "data" {
  count = length(local.nameServers) - 1
  zone = local.zone
  name = "${local.nameServers[count.index]}-data"
  type = "pd-ssd"
  size = local.sizeDiskData
}

resource "google_compute_disk" "log" {
  count = length(local.nameServers) - 1
  zone = local.zone
  name = "${local.nameServers[count.index]}-log"
  type = "pd-ssd"
  size = local.sizeDiskLog
}

resource "google_compute_attached_disk" "data" {
  count = length(local.nameServers) - 1
  disk = google_compute_disk.data[count.index].self_link
  instance = google_compute_instance.vm[count.index].self_link
}

resource "google_compute_attached_disk" "log" {
  count = length(local.nameServers) - 1
  disk = google_compute_disk.log[count.index].self_link
  instance = google_compute_instance.vm[length(local.nameServers) - 1].self_link
}
