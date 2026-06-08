terraform {
  required_providers {
    google = {
      version = "~> 7.28"
    }

    google-beta = {
      version = "~> 7.28"
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
  sample_name = "pass26"

  project_id_demo = var.project_id_demo
  project_id_demo4 = var.project_id_demo4
  project_id_demo4_n2 = var.project_id_demo4_n2
  project_id_demo4_c3 = var.project_id_demo4_c3
  project_id_demo4_c4 = var.project_id_demo4_c4
  project_id_demo4_c4n = var.project_id_demo4_c4n

  region_demo = var.region_demo
  region_demo4 = var.region_demo4
  region_demo4_n2 = var.region_demo4_n2
  region_demo4_c3 = var.region_demo4_c3
  region_demo4_c4 = var.region_demo4_c4
  region_demo4_c4n = var.region_demo4_c4n

  zone_demo = var.zone_demo
  zone_demo4 = var.zone_demo4
  zone_demo4_n2 = var.zone_demo4_n2
  zone_demo4_c3 = var.zone_demo4_c3
  zone_demo4_c4 = var.zone_demo4_c4
  zone_demo4_c4n = var.zone_demo4_c4n

  domain_name = "pass.lab"

  enable_demo4 = var.enable_demo4
  enable_demo4_n2 = var.enable_demo4_n2
  enable_demo4_c3 = var.enable_demo4_c3
  enable_demo4_c4 = var.enable_demo4_c4
  enable_demo4_c4n = var.enable_demo4_c4n
}

module "project" {
  source = "../../modules/project"
  count = local.project_id_demo != null ? 0 : 1

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = "pass26"

  apis = [
    "compute.googleapis.com",
    "run.googleapis.com"
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
  password = var.password

  enable_domain = false
  enable_ssms = true
  enable_hammerdb = false
  enable_discoveryclient = false

  depends_on = [
    google_compute_network.network,
    google_compute_subnetwork.subnetwork
  ]
}
