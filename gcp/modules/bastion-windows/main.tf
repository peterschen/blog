provider "google" {
  version = "~> 3.4"
}

locals {
  project = var.project
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  password = var.password
  machine-type = var.machine-type
  name-domain = var.name-domain
  enable-domain = var.enable-domain
}

module "gce-default-scopes" {
  source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
}

module "sysprep" {
  source = "github.com/peterschen/blog//gcp/modules/sysprep"
}

module "apis" {
  source = "github.com/peterschen/blog//gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_instance" "bastion" {
  project = local.project
  zone = local.zone
  name = "bastion-windows"
  machine_type = local.machine-type

  tags = ["bastion-windows", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = local.network
    subnetwork = local.subnetwork
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
      nameHost = "bastion-windows", 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path-meta),
        inlineConfiguration = filebase64("${path.module}/bastion.ps1"),
        nameDomain = local.name-domain,
        enableDomain = local.enable-domain
      })
    })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  depends_on = [module.apis]
}
