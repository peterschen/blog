terraform {
  required_providers {
    google = {
      version = "~> 7.28"
    }

    google-beta = {
      version = "~> 7.28"
    }
  }
}

provider "google" {
  add_terraform_attribution_label = false
}

provider "google-beta" {
  add_terraform_attribution_label = false
}

locals {
  sample_name = "pass26"

  project_id_demo1 = var.project_id_demo1
  project_id_demo4 = var.project_id_demo4

  region_demo1 = var.region_demo1
  region_demo4 = var.region_demo4

  zone_demo1 = var.zone_demo1
  zone_demo4 = var.zone_demo4

  domain_name = "pass.lab"

  enable_demo1 = var.enable_demo1
  enable_demo4 = var.enable_demo4
}
