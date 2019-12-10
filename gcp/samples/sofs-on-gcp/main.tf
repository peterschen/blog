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

resource "google_compute_instance" "sofs-primary" {
   name         = "sofs-1"
   machine_type = "n1-standard-2"

  tags = ["sample-${local.name-sample}-sofs-1", "rdp"]

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
    sysprep-specialize-script-ps1 = templatefile("${module.ad-on-gcp.path-module}/specialize.ps1", { 
        nameHost = "sofs-1", 
        nameDomain = var.name-domain,
        nameConfiguration = "sofs-primary",
        uriMeta = var.uri-meta,
        uriConfigurations = var.uri-configurations,
        password = var.password 
      })
  }
}

resource "google_compute_instance" "sofs-secondaries" {
   count = 2
   name         = "sofs-${count.index + 2}"
   machine_type = "n1-standard-2"

  tags = ["sample-${local.name-sample}-sofs-${count.index + 2}", "rdp"]

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
    sysprep-specialize-script-ps1 = templatefile("${module.ad-on-gcp.path-module}/specialize.ps1", { 
        nameHost = "sofs-${count.index + 2}", 
        nameDomain = var.name-domain,
        nameConfiguration = "sofs-secondaries",
        uriMeta = var.uri-meta,
        uriConfigurations = var.uri-configurations,
        password = var.password 
      })
  }
}
