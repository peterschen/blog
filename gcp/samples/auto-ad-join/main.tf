
terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
  project = var.project
}

locals {
  regions = var.regions
  zones = var.zones
  name-sample = "auto-ad-join"
  name-domain = var.domain-name
  password = var.password
  network-prefixes = ["10.0.0", "10.1.0"]
  network-mask = 16
  network-ranges = [
    for prefix in local.network-prefixes:
    "${prefix}.0/${local.network-mask}"
  ]
  network-range-serverless = "10.8.0.0/28"
  ip-dcs = [
    for prefix in local.network-prefixes:
    "${prefix}.2"
  ]
}

module "apis" {
  source = "../../modules/apis"
  apis = ["secretmanager.googleapis.com", "vpcaccess.googleapis.com", "run.googleapis.com", "cloudbuild.googleapis.com"]
}

module "cloud-nat" {
  count = length(local.regions)
  source = "../../modules/cloud-nat"
  region = local.regions[count.index]
  network = google_compute_network.network.name
  depends_on = [google_compute_network.network]
}

module "activedirectory" {
  source = "../../modules/activedirectory"
  regions = local.regions
  zones = local.zones
  network = google_compute_network.network.name
  subnetworks = [
    for subnet in google_compute_subnetwork.subnetworks:
    subnet.name
  ]
  name-domain = local.name-domain
  password = local.password
  depends_on = [module.cloud-nat]
}

module "firewall-iap" {
  source = "../../modules/firewall-iap"
  network = google_compute_network.network.name
  enable-ssh = false
}

module "firewall-ad" {
  source = "../../modules/firewall-ad"
  name = "allow-ad-serverless"
  network = google_compute_network.network.name
  cidr-ranges = [
    local.network-range-serverless
  ]
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetworks" {
  count = length(local.regions)
  region = local.regions[count.index]
  name = local.regions[count.index]
  ip_cidr_range = local.network-ranges[count.index]
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    for range in local.network-ranges:
    range
  ]
}

resource "google_vpc_access_connector" "adjoin-connector" {
  name = "adjoin-connector"
  region = local.regions[0]
  ip_cidr_range = local.network-range-serverless
  network = google_compute_network.network.name
  depends_on = [module.apis]
}

resource "google_secret_manager_secret" "adjoin-password" {
  secret_id = "adjoin-password"

  replication {
    automatic = true
  }

  depends_on = [module.apis]
}
