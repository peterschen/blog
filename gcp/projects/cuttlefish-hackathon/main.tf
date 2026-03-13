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

# TODO (Christoph): Apply on the AR not projet
resource "google_project_iam_member" "controller_artifactregistry_reader" {
  project = data.google_project.project.project_id
  role = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.hackathon_controller.email}"
}

resource "google_project_iam_member" "controller_logging_logwriter" {
  project = data.google_project.project.project_id
  role = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.hackathon_controller.email}"
}

# TODO (Christoph): Apply on the database not projet
resource "google_project_iam_member" "controller_firestore_user" {
  project = data.google_project.project.project_id
  role = "roles/datastore.user"
  member = "serviceAccount:${google_service_account.hackathon_controller.email}"
}

# TODO (Christoph): Apply on the bucket not project
resource "google_project_iam_member" "controller_storage_admin" {
  project = data.google_project.project.project_id
  role = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.hackathon_controller.email}"
}

resource "google_service_account_iam_member" "controler_serviceaccounttokencreator" {
  service_account_id = google_service_account.hackathon_controller.id
  role = "roles/iam.serviceAccountTokenCreator"
  member = "serviceAccount:${google_service_account.hackathon_controller.email}"
}

# Required for Cloud Build to access its storage bucket
resource "google_project_iam_member" "storage_user" {
  project = data.google_project.project.project_id
  role = "roles/storage.objectUser"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# Required for Cloud Build to push images to Artifact Registry
resource "google_project_iam_member" "artifactregistry_createonpushwriter" {
  project = data.google_project.project.project_id
  role = "roles/artifactregistry.createOnPushWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# resource "google_project_iam_member" "logging_logwriter" {
#   project = data.google_project.project.project_id
#   role = "roles/logging.logWriter"
#   member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
# }

# resource "google_project_iam_member" "run_developer" {
#   project = data.google_project.project.project_id
#   role = "roles/run.developer"
#   member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
# }

# resource "google_project_iam_member" "firestore_user" {
#   project = data.google_project.project.project_id
#   role = "roles/datastore.user"
#   member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
# }

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

resource "google_storage_bucket" "bucket" {
  project = data.google_project.project.project_id
  name = data.google_project.project.project_id
  location = local.region
  uniform_bucket_level_access = true
  public_access_prevention = "enforced"
  force_destroy = false
}

resource "google_artifact_registry_repository" "repository" {
  project = data.google_project.project.project_id
  repository_id = data.google_project.project.project_id
  location = local.region
  format = "DOCKER"
}

resource "google_cloud_run_v2_service" "api" {
  provider = google-beta
  project = data.google_project.project.project_id
  location = local.region
  name = "hackathon-controller-api"
  deletion_protection = false
  invoker_iam_disabled = true
  ingress = "INGRESS_TRAFFIC_ALL"
  iap_enabled = true

  template {
    containers {
      image = "${google_artifact_registry_repository.repository.registry_uri}/api:latest"
      env {
        name = "DATABASE_NAME"
        value = "${google_firestore_database.database.name}"
      }
      env {
        name = "BUCKET_NAME"
        value = "${google_storage_bucket.bucket.name}"
      }
    }
    service_account = google_service_account.hackathon_controller.email
  }
}

resource "google_cloud_run_v2_service" "proxy" {
  provider = google-beta
  project = data.google_project.project.project_id
  location = local.region
  name = "hackathon-controller-proxy"
  deletion_protection = false
  invoker_iam_disabled = true
  ingress = "INGRESS_TRAFFIC_ALL"
  iap_enabled = false

  template {
    containers {
      image = "${google_artifact_registry_repository.repository.registry_uri}/proxy:latest"
      env {
        name = "API_URI"
        value = "${google_cloud_run_v2_service.api.urls[0]}"
      }
    }
    service_account = google_service_account.hackathon_controller.email
  }
}

resource "google_cloud_run_v2_service" "ui" {
  provider = google-beta
  project = data.google_project.project.project_id
  location = local.region
  name = "hackathon-controller-ui"
  deletion_protection = false
  invoker_iam_disabled = true
  ingress = "INGRESS_TRAFFIC_ALL"
  iap_enabled = true

  template {
    containers {
      image = "${google_artifact_registry_repository.repository.registry_uri}/ui:latest"
      env {
        name = "API_URI"
        value = "${google_cloud_run_v2_service.api.urls[0]}"
      }
    }
    service_account = google_service_account.hackathon_controller.email
  }
}

resource "google_cloud_run_v2_service_iam_member" "api" {
  provider = google-beta
  project = data.google_project.project.project_id
  location = local.region
  name = google_cloud_run_v2_service.api.name
  role   = "roles/run.invoker"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "proxy" {
  provider = google-beta
  project = data.google_project.project.project_id
  location = local.region
  name = google_cloud_run_v2_service.proxy.name
  role   = "roles/run.invoker"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "ui" {
  provider = google-beta
  project = data.google_project.project.project_id
  location = local.region
  name = google_cloud_run_v2_service.ui.name
  role   = "roles/run.invoker"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_iap_web_cloud_run_service_iam_binding" "api" {
  project = data.google_project.project.project_id
  location = local.region
  cloud_run_service_name = google_cloud_run_v2_service.api.name
  role = "roles/iap.httpsResourceAccessor"
  members = [
    "allAuthenticatedUsers"
  ]  
}

resource "google_iap_web_cloud_run_service_iam_binding" "ui" {
  project = data.google_project.project.project_id
  location = local.region
  cloud_run_service_name = google_cloud_run_v2_service.ui.name
  role = "roles/iap.httpsResourceAccessor"
  members = [
    "user:christoph@cbpetersen.altostrat.com"
  ]  
}

module "project_sandbox" {
  source = "../../modules/project"
  count = local.project_id != null ? 0 : 1

  org_id = var.org_id
  billing_account = var.billing_account

  name = "${local.project_name}-${resource.random_integer.project[0].id}-sandbox"

  apis = [
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ]
}

data "google_compute_default_service_account" "default_sandbox" {
  project = module.project_sandbox[0].id
}

resource "google_project_iam_member" "logging_logwriter_sandbox" {
  project = module.project_sandbox[0].id
  role = "roles/logging.logWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default_sandbox.email}"
}

resource "google_project_iam_member" "logging_metricwriter_sandbox" {
  project = module.project_sandbox[0].id
  role = "roles/monitoring.metricWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default_sandbox.email}"
}

resource "google_project_iam_member" "storage_user_sandbox" {
  project = module.project[0].id
  role = "roles/storage.objectUser"
  member = "serviceAccount:${data.google_compute_default_service_account.default_sandbox.email}"
}
