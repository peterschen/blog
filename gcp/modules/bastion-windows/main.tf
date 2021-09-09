locals {
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  password = var.password
  machine-type = var.machine-type
  machine-name = var.machine-name
  name-domain = var.domain-name
  enable-domain = var.enable-domain
  enable-ssms = var.enable-ssms
  enable-hammerdb = var.enable-hammerdb
  enable-diskspd = var.enable-diskspd
}

data "google_compute_network" "network" {
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  region = local.region
  name = local.subnetwork
}

module "gce-default-scopes" {
  # source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
  source = "../gce-default-scopes"
}

module "sysprep" {
  # source = "github.com/peterschen/blog//gcp/modules/sysprep"
  source = "../sysprep"
}

module "apis" {
  # source = "github.com/peterschen/blog//gcp/modules/apis"
  source = "../apis"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_instance" "bastion" {
  zone = local.zone
  name = local.machine-name
  machine_type = local.machine-type

  tags = ["bastion-windows", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019-for-containers"
      type = "pd-balanced"
    }
  }

  network_interface {
    network = local.network
    subnetwork = local.subnetwork
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
      nameHost = local.machine-name, 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path-meta),
        inlineConfiguration = filebase64("${path.module}/bastion.ps1"),
        nameDomain = local.name-domain,
        enableDomain = local.enable-domain,
        enableSsms = local.enable-ssms,
        enableHammerdb = local.enable-hammerdb,
        enableDiskspd = local.enable-diskspd
      })
    })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
