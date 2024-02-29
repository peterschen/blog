provider "google" {
}

locals {
  project_prefix = var.project_prefix
  region = var.region
  zone = var.zone
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.project_prefix

  apis = [
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = "default"
  auto_create_subnetworks = true
}

resource "google_storage_bucket" "bucket" {
  project = module.project.id
  name = module.project.name
  location = local.region

  force_destroy = true
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true
}

resource "google_project_service_identity" "cloudbuild_sa" {
  provider = google-beta
  project = module.project.name
  service = "cloudbuild.googleapis.com"
}

resource "google_project_iam_member" "cloudbuild_instanceadmin" {
  project = module.project.id
  role  = "roles/compute.instanceAdmin.v1"
  member = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_serviceaccountuser" {
  project = module.project.id
  role  = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"
}

resource "google_storage_bucket_iam_member" "bucket_objectuser" {
  bucket = google_storage_bucket.bucket.name
  role = "roles/storage.objectUser"
  member = "serviceAccount:${google_project_service_identity.cloudbuild_sa.email}"
}
