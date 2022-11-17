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
  region = var.region
  network_range = "10.0.0.0/16"
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "managedidentities.googleapis.com"
  ]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = module.project.id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetworks" {
  project = module.project.id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network.id
  private_ip_google_access = true
}
