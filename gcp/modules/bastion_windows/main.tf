locals {
  project = var.project
  project_network = var.project_network
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  password = var.password
  machine_type = var.machine_type
  machine_name = var.machine_name
  domain_name = var.domain_name

  windows_image = var.windows_image

  enable_domain = var.enable_domain
  enable_ssms = var.enable_ssms
  enable_hammerdb = var.enable_hammerdb
  enable_diskspd = var.enable_diskspd
  enable_python = var.enable_python
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

module "gce_scopes" {
  source = "../gce_scopes"
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
  name = local.machine_name
  machine_type = local.machine_type

  tags = ["bastion-windows", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
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
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
      nameHost = local.machine_name, 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path-meta),
        inlineConfiguration = filebase64("${path.module}/bastion.ps1"),
        nameDomain = local.domain_name,
        enableDomain = local.enable_domain,
        enableSsms = local.enable_ssms,
        enableHammerdb = local.enable_hammerdb,
        enableDiskspd = local.enable_diskspd,
        enablePython = local.enable_python
      })
    })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
