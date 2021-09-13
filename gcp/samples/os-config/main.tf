terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
  project = var.project
}

locals {
  region = var.region
  zone = var.zone
}

resource "google_compute_project_metadata_item" "metadata" {
  for_each = {
    enable-osconfig = "true",
    osconfig-log-level = "debug"
  }

  key = each.key
  value = each.value
}
