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
  count-instances = 2
}

data "google_client_config" "current" {}

resource "google_compute_instance" "wd" {
  count = local.count-instances
  zone = "${var.region}-${var.zones[count.index]}"
  name = "wd-${count.index}"
  machine_type = "n1-standard-1"

  tags = ["sample-${var.name-sample}-wd", "dmz"]

  boot_disk {
    initialize_params {
      image = "suse-cloud/sles-15"
    }
  }

  network_interface {
    network = var.name-network
    subnetwork = var.name-subnet
  }

  metadata = {
    type = "wd"
  }
}
