provider "google" {
}

locals {
  region = var.region
  prefix = var.prefix
  zone = var.zone

  sample_name = "protect-snapshots"

  network_range = "10.11.0.0/16"

  machine_type = "e2-medium"
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "workflows.googleapis.com"
  ]
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
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

# data "external" "disk" {
#   program = ["gcloud", "compute", "disks", "describe", "${google_compute_disk.disk.name}", "--project=${module.project.id}", "--format=json(id)"]
#   depends_on = [ google_compute_disk.disk ]
# }

# resource "google_tags_location_tag_binding" "disk" {
#   parent = "//compute.googleapis.com/projects/${module.project.id}/zones/${local.zone}/disks/${data.external.disk.result.id}"
#   tag_value = "tagValues/${google_tags_tag_value.payg.name}"
#   location = local.zone
# }

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
  name = "worklaod"
  machine_type = local.machine_type

  tags = ["ssh"]

  boot_disk {
    source = google_compute_disk.workload.name
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
