provider "google" {
  version = "~> 3.4"
}

locals {
  project = var.project
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  uri-meta = var.uri-meta
  password = var.password
}

module "sysprep" {
  source = "github.com/peterschen/blog/gcp/modules/sysprep"
}

module "apis" {
  source = "github.com/peterschen/blog/gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_instance" "bastion" {
  project = local.project
  zone = local.zone
  name = "bastion-windows"
  machine_type = "n1-standard-2"

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
      nameHost = "bastion", 
      uriMeta = local.uri-meta,
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineConfiguration = filebase64("${path.module}/bastion.ps1")
      })
    })
  }

  depends_on = [module.apis]
}
