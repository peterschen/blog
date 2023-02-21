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
