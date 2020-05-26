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
  uri-meta = var.uri-meta
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

  tags = ["bastion-windows"]

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
      uriMeta = local.uri-meta,
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineConfiguration = filebase64("${path.module}/bastion.ps1")
      })
    })
  }

  depends_on = [module.apis]
}
