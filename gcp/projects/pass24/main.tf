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
  project_id_demo1 = var.project_id_demo1
  project_id_demo3 = var.project_id_demo3
  project_id_demo4 = var.project_id_demo4

  region_demo1 = var.region_demo1
  region_demo3 = var.region_demo3
  region_demo4 = var.region_demo4

  region_secondary_demo3 = var.region_secondary_demo3

  zone_demo1 = var.zone_demo1
  zone_demo3 = var.zone_demo3
  zone_demo4 = var.zone_demo4

  zone_secondary_demo3 = var.zone_secondary_demo3

  domain_name = "pass24.lab"

  enable_demo1 = var.enable_demo1
  enable_demo3 = var.enable_demo3
  enable_demo4 = var.enable_demo4
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
