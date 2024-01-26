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
    "compute.googleapis.com"
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

resource "google_tags_tag_key" "image_type" {
  parent = "projects/${module.project.id}"
  short_name = "image_type"
}

resource "google_tags_tag_value" "byol" {
  parent = "tagKeys/${google_tags_tag_key.image_type.name}"
  short_name = "BYOL"
}

resource "google_tags_tag_value" "payg" {
  parent = "tagKeys/${google_tags_tag_key.image_type.name}"
  short_name = "PAYG"
}

# resource "google_iam_deny_policy" "deny_byol_images" {
#   parent = urlencode("cloudresourcemanager.googleapis.com/projects/${module.project.id}")

#   name  = "deny-byol-images"
#   display_name = "Denies VM start() operation when using untagged images"

#   rules {
#     deny_rule {
#       denied_principals = ["principalSet://goog/public:all"]
      
#       denial_condition {
#         # resource.type == "compute.googleapis.com/Image" &&
#         expression = <<EOT
#           !resource.matchTagId("${google_tags_tag_key.image_type.id}", "${google_tags_tag_value.payg.id}")
#         EOT
#       }
      
#       denied_permissions = ["compute.googleapis.com/images.create"]
#     }
#   }
# }

# resource "google_compute_disk" "disk" {
#   project = module.project.id
#   name  = "disk"
#   type = "pd-balanced"
#   zone = local.zone
#   image = "family/debian-12"
# }

# data "external" "disk" {
#   program = ["gcloud", "compute", "disks", "describe", "${google_compute_disk.disk.name}", "--project=${module.project.id}", "--format=json(id)"]
#   depends_on = [ google_compute_disk.disk ]
# }

# resource "google_tags_location_tag_binding" "disk" {
#   parent = "//compute.googleapis.com/projects/${module.project.id}/zones/${local.zone}/disks/${data.external.disk.result.id}"
#   tag_value = "tagValues/${google_tags_tag_value.payg.name}"
#   location = local.zone
# }

resource "google_iam_deny_policy" "deny_untagged_disks" {
  parent = urlencode("cloudresourcemanager.googleapis.com/projects/${module.project.id}")

  name  = "deny-untagged-disks"
  display_name = "Denies VM start() operation when using untagged disks"

  rules {
    deny_rule {
      denied_principals = ["principalSet://goog/public:all"]
      
      denial_condition {
        # resource.type == "compute.googleapis.com/Disk" &&        
        expression = <<EOT
          !resource.matchTagId("${google_tags_tag_key.image_type.id}", "${google_tags_tag_value.payg.id}")
        EOT
      }
      
      denied_permissions = ["compute.googleapis.com/disks.create"]
    }
  }

  # depends_on = [ google_tags_location_tag_binding.disk ]
}

resource "google_compute_instance" "from_image_without_tag" {
  project = module.project.id
  zone = local.zone
  name = "instance-from-image-without-tag"
  machine_type = local.machine_type

  tags = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
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

  depends_on = [ 
    google_iam_deny_policy.deny_untagged_disks
  ]
}

resource "google_compute_instance" "from_disk_with_tag" {
  project = module.project.id
  zone = local.zone
  name = "instance-from-disk-with-tag"
  machine_type = local.machine_type

  tags = ["ssh"]

  boot_disk {
    # Disk is created outside of Terraform, this resource will fail until the resource has been created
    source = "projects/${module.project.id}/zones/${local.zone}/disks/disk-with-tag"
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

  depends_on = [ 
    google_iam_deny_policy.deny_untagged_disks
  ]
}
