terraform {
  required_providers {
    google = {
      version = "~> 6.40"
    }

    google-beta = {
      version = "~> 6.40"
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
  sample_name = "pass25"

  project_id_demo = var.project_id_demo
  project_id_demo1 = var.project_id_demo1
  project_id_demo2 = var.project_id_demo2
  project_id_demo3 = var.project_id_demo3
  project_id_demo4 = var.project_id_demo4

  region_demo = var.region_demo
  region_demo1 = var.region_demo1
  region_demo2 = var.region_demo2
  region_demo3 = var.region_demo3
  region_demo4 = var.region_demo4

  region_secondary_demo3 = var.region_secondary_demo3

  zone_demo = var.zone_demo
  zone_demo1 = var.zone_demo1
  zone_demo2 = var.zone_demo2
  zone_demo3 = var.zone_demo3
  zone_demo4 = var.zone_demo4

  zone_secondary_demo2 = var.zone_secondary_demo2
  zone_secondary_demo3 = var.zone_secondary_demo3

  domain_name = "pass.lab"

  enable_demo1 = var.enable_demo1
  enable_demo2 = var.enable_demo2
  enable_demo3 = var.enable_demo3
  enable_demo4 = var.enable_demo4
}

module "project" {
  source = "../../modules/project"
  count = local.project_id_demo != null ? 0 : 1

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = "passdemo"

  apis = [
    "compute.googleapis.com",
  ]
}

data "google_project" "project" {
  project_id = local.project_id_demo != null ? local.project_id_demo : module.project[0].id
}

data "google_compute_default_service_account" "default" {
  project = data.google_project.project.project_id
}

# If the project is created outside of this configuration
# make sure that all necessary APIs are enabled
resource "google_project_service" "apis" {
  project = data.google_project.project.project_id
  service = "compute.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_compute_network" "network" {
  project = data.google_project.project.project_id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = data.google_project.project.project_id
  region = local.region_demo
  name = local.region_demo
  ip_cidr_range = "10.0.0.0/16"
  network = google_compute_network.network.id
  private_ip_google_access = true
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = data.google_project.project.project_id
  network = google_compute_network.network.name
  enable_rdp = true
  enable_ssh = true
}

resource "google_compute_firewall" "allow-all-internal" {
  name = "allow-all-internal"
  project = data.google_project.project.project_id

  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    "10.0.0.0/16"
  ]
}

module "nat" {
  source = "../../modules/nat"
  project = data.google_project.project.project_id

  region = local.region_demo
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  project = data.google_project.project.project_id

  region = local.region_demo
  zone = local.zone_demo

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  machine_type = "n4-standard-4"
  machine_name = "bastion"

  domain_name = local.domain_name
  password = "Admin123Admin123"

  enable_domain = false
  enable_ssms = false
  enable_hammerdb = false
  enable_discoveryclient = false
}