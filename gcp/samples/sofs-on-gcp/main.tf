provider "google" {
  version = "~> 3.1"
  project = "${var.project}"
}

provider "google-beta" {
  version = "~> 3.1"
  project = "${var.project}"
}

locals {
  name-sample = "sofs-on-gcp"
  count-instances = 3
}

module "ad-on-gcp" {
  source = "github.com/peterschen/blog/gcp/samples/ad-on-gcp"
  project = var.project
  regions = var.regions
  zones = var.zones
  name-domain = var.name-domain
  password = var.password
}

resource "google_compute_instance" "sofs" {
  count = local.count-instances
  zone = "${var.regions[0]}-${var.zones[count.index]}"
  name = "sofs-${count.index}"
  machine_type = "n1-standard-2"

  tags = ["rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = module.ad-on-gcp.network
    subnetwork = module.ad-on-gcp.subnets[0]
  }

  metadata = {
    sample = local.name-sample
    type = "sofs"
    sysprep-specialize-script-ps1 = templatefile("${module.ad-on-gcp.path-module}/specialize.ps1", { 
        nameHost = "sofs-${count.index}", 
        nameConfiguration = "sofs",
        uriMeta = var.uri-meta,
        uriConfigurations = var.uri-configurations,
        password = var.password,
        parametersConfiguration = jsonencode({
          domainName = var.name-domain,
          isFirst = (count.index == 0)
        })
      })
  }
}
