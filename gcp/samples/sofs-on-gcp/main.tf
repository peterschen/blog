provider "google" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
  zone = "${var.zone}"
}

provider "google-beta" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
  zone = "${var.zone}"
}

locals {
  name-sample = "sofs-on-gcp"
}

data "google_client_config" "current" {}

module "ad-on-gcp" {
  source = "github.com/peterschen/blog/gcp/samples/ad-on-gcp"
  project = var.project
  name-domain = var.name-domain
  password = var.password
}

resource "google_compute_instance" "sofs1" {
   name         = "sofs1"
   machine_type = "n1-standard-2"

  tags = ["sample-${local.name-sample}-sofs", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = module.ad-on-gcp.network
    subnetwork = module.ad-on-gcp.subnet
  }

  metadata = {
    sample                        = local.name-sample
    type                          = "sofs"
    sysprep-specialize-script-ps1 = templatefile("specialize.ps1", { 
        nameHost = "sofs1", 
        nameDomain = var.name-domain,
        nameConfiguration = "sofs",
        uriConfigurations = var.uri-configurations,
        password = var.password 
      })
  }

  depends_on = ["module.ad-on-gcp"]
}
