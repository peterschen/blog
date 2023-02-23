terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
}

locals {
  network_range = "10.12.0.0/16"
  region = var.region
  zone = var.zone

  scenarios = var.scenarios
}

module "project" {
  count = length(local.scenarios)
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account
  prefix = local.scenarios[count.index].name

  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com"
  ]
}

resource "google_compute_network" "network" {
  count = length(local.scenarios)
  project = module.project[count.index].id
  name = local.scenarios[count.index].name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  count = length(local.scenarios)
  project = module.project[count.index].id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network[count.index].id
  private_ip_google_access = true
}

resource "google_compute_instance" "vm" {
  count = length(local.scenarios)
  project = module.project[count.index].id
  zone = local.zone
  name = local.scenarios[count.index].name
  machine_type = local.scenarios[count.index].shape

  tags = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.network[count.index].id
    subnetwork = google_compute_subnetwork.subnetwork[count.index].id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  allow_stopping_for_update = true  
}
