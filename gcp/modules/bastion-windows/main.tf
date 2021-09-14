locals {
  project = var.project
  projectNetwork = var.projectNetwork
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  password = var.password
  machineType = var.machine-type
  machineName = var.machine-name
  nameDomain = var.domain-name
  enableDomain = var.enable-domain
  enableSsms = var.enable-ssms
  enableHammerdb = var.enable-hammerdb
  enableDiskspd = var.enable-diskspd
}

data "google_compute_network" "network" {
  project = local.projectNetwork
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  project = local.projectNetwork
  region = local.region
  name = local.subnetwork
}

module "gceDefaultScopes" {
  source = "../gce-default-scopes"
}

module "sysprep" {
  source = "../sysprep"
}

module "apis" {
  source = "../apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_instance" "bastion" {
  project = local.project
  zone = local.zone
  name = local.machineName
  machine_type = local.machineType

  tags = ["bastion-windows", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019-for-containers"
      type = "pd-balanced"
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
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
      nameHost = local.machineName, 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path-meta),
        inlineConfiguration = filebase64("${path.module}/bastion.ps1"),
        nameDomain = local.nameDomain,
        enableDomain = local.enableDomain,
        enableSsms = local.enableSsms,
        enableHammerdb = local.enableHammerdb,
        enableDiskspd = local.enableDiskspd
      })
    })
  }

  service_account {
    scopes = module.gceDefaultScopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
