provider "google" {
  version = "~> 3.4"
}

locals {
  project = var.project
  zone = var.zone
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
  name = "bastion"
  machine_type = "n1-standard-2"

  tags = ["bastion", "rdp"]

  boot_disk {
    initialize_params {
      type = "pd-ssd"
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = var.network
    subnetwork = var.subnetwork
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
      nameHost = "bastion", 
      nameConfiguration = "bastion",
      uriMeta = var.uri-meta,
      uriConfigurations = var.uri-configuration,
      password = var.password,
      parametersConfiguration = jsonencode({})
    })
  }

  depends_on = ["module.apis"]
}
