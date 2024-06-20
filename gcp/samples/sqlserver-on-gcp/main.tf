terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
}

locals {
  prefix = var.prefix
  region = var.region
  zones = var.zones
  sample_name = "sqlserver-on-gcp"
  
  domain_name = var.domain_name
  password = var.password

  windows_image = var.windows_image
  windows_core_image = var.windows_core_image
  sql_image = var.sql_image

  network_range = "10.0.0.0/16"

  machine_type_dc = "n2-highcpu-2"
  machine_type_bastion = "n2-standard-4"
  machine_type_sql = "n2-standard-4"

  enable_cluster = var.enable_cluster
  enable_alwayson = var.enable_alwayson
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "dns.googleapis.com"
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

module "nat" {
  source = "../../modules/nat"
  project = module.project.id

  region = local.region
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "ad" {
  source = "../../modules/ad"
  project = module.project.id

  regions = [local.region]
  zones = local.zones

  network = google_compute_network.network.name
  subnetworks = [
    google_compute_subnetwork.subnetwork.name
  ]

  domain_name = local.domain_name
  machine_type = local.machine_type_dc

  windows_image = local.windows_core_image

  password = local.password
  enable_ssl = false

  depends_on = [
    module.nat
  ]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  project = module.project.id

  region = local.region
  zone = local.zones[0]

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  machine_type = local.machine_type_bastion
  machine_name = "bastion"

  windows_image = local.windows_image

  domain_name = local.domain_name
  password = local.password

  enable_domain = true
  enable_discoveryclient = false

  depends_on = [
    module.ad
  ]
}

module "sqlserver" {
  source = "../../modules/sqlserver"
  project = module.project.id
  region = local.region
  zones = local.zones
  
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name
  
  domain_name = local.domain_name
  password = local.password
  
  windows_image = local.sql_image
  machine_type = local.machine_type_sql

  enable_cluster = local.enable_cluster
  enable_alwayson = local.enable_alwayson
  depends_on = [module.ad]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
  enable_ssh = false
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  project = module.project.id

  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range
  ]
}
