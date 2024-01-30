provider "google" {
}

locals {
  region = var.region
  region_scheduler = var.region_scheduler
  prefix = var.prefix
  zone = var.zone

  sample_name = "protect-snapshots"

  network_range = "10.11.0.0/16"

  machine_type = "e2-medium"

  retention = var.retention
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "pubsub.googleapis.com",
    "workflows.googleapis.com",
    "logging.googleapis.com"
  ]
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
}

resource "google_service_account" "snapshot_automation" {
  project = module.project.id
  account_id = "snapshot-automation"
  display_name = "Service account for snapshot automation (tagging/untagging)"
}

resource "google_project_iam_member" "pubsub_serviceAccountTokenCreator" {
  project = module.project.id
  role = "roles/iam.serviceAccountTokenCreator"
  member = "serviceAccount:service-${module.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "storageAdmin" {
  project = module.project.id
  role = "roles/compute.storageAdmin"
  member = "serviceAccount:${google_service_account.snapshot_automation.email}"
}

resource "google_project_iam_member" "workflowsInvoker" {
  project = module.project.id
  role = "roles/workflows.invoker"
  member = "serviceAccount:${google_service_account.snapshot_automation.email}"
}

resource "google_project_iam_member" "loggingLogWriter" {
  project = module.project.id
  role = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.snapshot_automation.email}"
}

resource "google_project_iam_member" "tagUser" {
  project = module.project.id
  role = "roles/resourcemanager.tagUser"
  member = "serviceAccount:${google_service_account.snapshot_automation.email}"
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = module.project.id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network.id
  private_ip_google_access = true
}

resource "google_tags_tag_key" "protection" {
  parent = "projects/${module.project.id}"
  short_name = "protection"
}

resource "google_tags_tag_value" "enabled" {
  parent = "tagKeys/${google_tags_tag_key.protection.name}"
  short_name = "enabled"
}

resource "google_tags_tag_value" "disabled" {
  parent = "tagKeys/${google_tags_tag_key.protection.name}"
  short_name = "disabled"
}

resource "google_tags_tag_binding" "enabled" {
    parent = "//cloudresourcemanager.googleapis.com/projects/${module.project.number}"
    tag_value = "tagValues/${google_tags_tag_value.enabled.name}"
}

resource "google_compute_resource_policy" "snapshot" {
  project = module.project.id
  name = "snapshot-hourly-30d-retention"
  region = local.region

  snapshot_schedule_policy {
    schedule {
      hourly_schedule {
        hours_in_cycle = 1
        start_time = "00:00"
      }
    }

    retention_policy {
      max_retention_days = 30
    }
  }
}

resource "google_compute_disk" "workload" {
  project = module.project.id
  name  = "workload"
  type = "pd-balanced"
  zone = local.zone
  image = "family/debian-12"
}

resource "google_compute_disk_resource_policy_attachment" "snapshot" {
  project = module.project.id
  name = google_compute_resource_policy.snapshot.name
  disk = google_compute_disk.workload.name
  zone = google_compute_disk.workload.zone
}

resource "google_compute_instance" "workload" {
  project = module.project.id
  zone = local.zone
  name = "workload"
  machine_type = local.machine_type

  tags = ["ssh"]

  boot_disk {
    source = google_compute_disk.workload.name
    auto_delete = false
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetwork.id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_iam_deny_policy" "deny_snapshot_delete" {
  parent = urlencode("cloudresourcemanager.googleapis.com/projects/${module.project.id}")

  name  = "deny-untagged-disks"
  display_name = "Denies VM start() operation when using untagged disks"

  rules {
    deny_rule {
      denied_principals = ["principalSet://goog/public:all"]
      
      denial_condition {
        expression = <<EOT
          resource.matchTagId("${google_tags_tag_key.protection.id}", "${google_tags_tag_value.enabled.id}")
        EOT
      }
      
      denied_permissions = [
        "compute.googleapis.com/snapshots.delete"
      ]
    }
  }
}

resource "google_workflows_workflow" "snapshot_release" {
  project = module.project.id
  region = local.region
  name = "snapshot-release"
  service_account = google_service_account.snapshot_automation.email
  source_contents = file("workflow.yaml")
}

resource "google_cloud_scheduler_job" "snapshot_release" {
  project = module.project.id
  region = local.region_scheduler
  name = "snapshot_release"
  schedule = "0 0,12 * * *"

  http_target {
    uri = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.snapshot_release.id}/executions"
    http_method = "POST"
    headers = {
      "Content-Type" = "application/octet-stream"
      "User-Agent" = "Google-Cloud-Scheduler"
    }
    body = base64encode(<<-EOM
        {
          "argument": "{
            \"project_id\": \"${module.project.id}\",
            \"tag_key\": \"${google_tags_tag_key.protection.id}\",
            \"tag_value\": \"${google_tags_tag_value.disabled.id}\",
            \"retention\": ${local.retention}
          }",
          "callLogLevel": "LOG_ALL_CALLS"
        }
      EOM
    )
    oauth_token {
      scope = "https://www.googleapis.com/auth/cloud-platform"
      service_account_email = google_service_account.snapshot_automation.email
    }
  }

  retry_config {
    retry_count = 0
  }
}