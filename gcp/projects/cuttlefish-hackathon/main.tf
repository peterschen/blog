terraform {
  required_providers {
    google = {
      version = "~> 7.11"
    }

    google-beta = {
      version = "~> 7.11"
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
  project_name = "axion-hackaton"
  project_id = var.project_id

  region = var.region
  zone = var.zone
}

resource "random_integer" "project" {
  count = local.project_id == null ? 1 : 0
  min = 1000
  max = 9999
}

module "project" {
  source = "../../modules/project"
  count = local.project_id != null ? 0 : 1

  org_id = var.org_id
  billing_account = var.billing_account

  name = "${local.project_name}-${resource.random_integer.project[0].id}"

  apis = [
    "run.googleapis.com",
    "firestore.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

data "google_project" "project" {
  project_id = local.project_id != null ? local.project_id : module.project[0].id
}

data "google_compute_default_service_account" "default" {
  project = data.google_project.project.project_id
}

resource "google_service_account" "hackathon_controller" {
  project = data.google_project.project.project_id
  account_id = "hackathon-controller"
}

resource "google_project_iam_member" "storage_user" {
  project = data.google_project.project.project_id
  role = "roles/storage.objectUser"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "artifactregistry_createonpushwriter" {
  project = data.google_project.project.project_id
  role = "roles/artifactregistry.createOnPushWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "logging_logwriter" {
  project = data.google_project.project.project_id
  role = "roles/logging.logWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "run_developer" {
  project = data.google_project.project.project_id
  role = "roles/run.developer"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "firestore_user" {
  project = data.google_project.project.project_id
  role = "roles/datastore.user"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_firestore_database" "database" {
  project = data.google_project.project.project_id
  location_id = local.region
  name = data.google_project.project.project_id
  type = "FIRESTORE_NATIVE"
  concurrency_mode = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy = "DELETE"
}
