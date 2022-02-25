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
  nameServer = "stratozone"
  machineType = var.machineType
  password = var.password
  enableDomain = var.enableDomain
  enableStratozone = var.enableStratozone
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

resource "google_compute_instance" "stratozone" {
  zone = local.zone
  name = local.nameServer
  machine_type = local.machineType

  tags = ["stratozone", "rdp"]

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
      nameHost = local.nameServer, 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path_meta),
        inlineConfiguration = filebase64("${path.module}/dsc.ps1"),
        nameDomain = local.nameDomain,
        enableDomain = local.enableDomain,
        enableStratozone = local.enableStratozone
      })
    })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true
}
