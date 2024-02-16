provider "google" {
}

locals {
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
    "config.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]
}

resource "google_project_service_identity" "config_sa" {
  provider = google-beta
  project = module.project.id
  service = "config.googleapis.com"
}

resource "google_service_account" "service_account" {
  project = module.project.id
  account_id = "inframanager"
}

resource "google_service_account_iam_member" "config_serviceagent" {
  service_account_id = google_service_account.service_account.id
  role  = "roles/cloudconfig.serviceAgent"
  member = "serviceAccount:${google_project_service_identity.config_sa.email}"
}

resource "google_project_iam_member" "agent" {
  project = module.project.id
  role = "roles/config.agent"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "owner" {
  project = module.project.id
  role = "roles/owner"
  member = "serviceAccount:${google_service_account.service_account.email}"
}
