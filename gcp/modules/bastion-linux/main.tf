provider "google" {
  version = "~> 3.4"
}

locals {
  project = var.project
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
}

module "apis" {
  source = "github.com/peterschen/blog/gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_firewall" "bastion-22" {
  project = local.project
  name = "bastion-linux-22"
  network = local.network
  priority = 2500

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["bastion-linux"]
}

resource "google_compute_instance" "bastion" {
  project = local.project
  zone = local.zone
  name = "bastion-linux"
  machine_type = "n1-standard-1"

  tags = ["bastion-linux"]

  boot_disk {
    initialize_params {
      type = "pd-ssd"
      image = "ubuntu-os-cloud/ubuntu-1904"
    }
  }

  network_interface {
    network = local.network
    subnetwork = local.subnetwork
  }

  metadata = {
    startup-script = '#!/bin/bash
    apt-get update
    apt-get install chrome -y'
  }

  depends_on = ["module.apis"]
}
