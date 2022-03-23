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
  name-sample = "sofs-on-gcp"
  name-domain = var.domain-name
  password = var.password
  network-prefixes = ["10.0.0", "10.1.0"]
  network-mask = 16
  network-ranges = [
    for prefix in local.network-prefixes:
    "${prefix}.0/${local.network-mask}"
  ]
  enable-cluster = var.enable-cluster
  enable_hdd = var.enable_hdd
  count-nodes = var.count-nodes

  ssd_count = var.ssd_count
  hdd_count = var.hdd_count
  ssd_size = var.ssd_size
  hdd_size = var.hdd_size
}

module "apis" {
  source = "../../modules/apis"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

module "nat" {
  count = length(local.regions)
  source = "../../modules/nat"
  region = local.regions[count.index]
  network = google_compute_network.network.name
  depends_on = [google_compute_network.network]
}

module "ad" {
  source = "../../modules/ad"
  regions = local.regions
  zones = local.zones
  network = google_compute_network.network.name
  subnetworks = [
    for subnet in google_compute_subnetwork.subnetworks:
    subnet.name
  ]
  domain_name = local.name-domain
  password = local.password
  depends_on = [module.nat]
}

module "sofs" {
  source = "../../modules/sofs"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  domain_name = local.name-domain
  password = local.password
  depends_on = [module.ad]

  node_count = local.count-nodes
  enable_hdd = local.enable_hdd
  enable_cluster = local.enable-cluster
  ssd_count = local.ssd_count
  ssd_size = local.ssd_size
}

module "bastion" {
  source = "../../modules/bastion_windows"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  machine_name = "bastion"
  password = local.password
  domain_name = local.name-domain
  enable_domain = true
  depends_on = [module.ad]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  network = google_compute_network.network.name
  enable_ssh = false
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
  depends_on = [module.apis]
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
