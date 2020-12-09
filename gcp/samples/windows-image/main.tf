provider "google" {
  version = "~> 3.1"
  project = var.project
}

locals {
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
}

data "google_compute_network" "network" {
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  region = local.region
  name = local.subnetwork
}

module "apis" {
  source = "github.com/peterschen/blog//gcp/modules/apis"
  apis = ["compute.googleapis.com", "servicemanagement.googleapis.com", "sourcerepo.googleapis.com", "cloudapis.googleapis.com", "storage-api.googleapis.com", "cloudbuild.googleapis.com"]
}

# resource "google_compute_firewall" "allow-winrm-internal" {
#   name = "allow-winrm-internal"
#   network = google_compute_network.network.name
#   priority = 1000

#   allow {
#     protocol = "tcp"
#     ports = [5986]
#   }

#   direction = "INGRESS"

#   source_ranges = [local.network-range, "0.0.0.0/0"]
# }

resource "google_cloudbuild_trigger" "master" {
  name = "windows-image"
  included_files = ["/gcp/samples/windows-image/**"]

  github {
    owner = "peterschen"
    repo_name = "blog"
    branch_name = "master"
  }

  filename = "blog/samples/windows-image/cloudbuild.yaml"
}
