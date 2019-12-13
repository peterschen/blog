provider "google" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
}

provider "google-beta" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
}

locals {
  name-prefix = "jb-rdp"
  count-instances = 2
}

data "google_client_config" "current" {}

resource "google_compute_instance" "jb-rdp" {
  count = local.count-instances
  zone = "${var.region}-${var.zones[count.index]}"
  name = "${local.name-prefix}-${count.index}"
  machine_type = "n1-standard-1"

  tags = ["sample-${var.name-sample}-${local.name-prefix}", "dmz"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = var.name-network
    subnetwork = var.name-subnet
  }

  metadata = {
    type = local.name-prefix
  }
}
