

provider "google" {
}

locals {
  region = var.region
  name = var.name
  prefix = var.prefix
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  name = local.name
  prefix = local.prefix

  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
  ]
}
