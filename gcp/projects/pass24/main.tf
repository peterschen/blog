terraform {
  required_providers {
    google = {
      version = "~> 5.0"
    }
  }
}

provider "google" {
}

provider "google-beta" {
}

locals {
  project_id_demo5 = var.project_id_demo5
  project_id_demo6 = var.project_id_demo6

  region_demo5 = var.region_demo5
  region_demo6 = var.region_demo6

  region_secondary_demo5 = var.region_secondary_demo5

  zone_demo5 = var.zone_demo5
  zone_demo6 = var.zone_demo6

  zone_secondary_demo5 = var.zone_secondary_demo5

  domain_name = "pass24.lab"

  enable_demo5 = var.enable_demo5
  enable_demo6 = var.enable_demo6
}

# resource "google_compute_disk" "data" {
#   count = 2
#   provider = google-beta
#   project = data.google_project.project.project_id
#   region = local.region
#   name = "data-${count.index}"
#   type = "hyperdisk-balanced-high-availability"
#   access_mode = "READ_WRITE_MANY"
# }
