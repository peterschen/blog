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
  sample_name = "sofs-on-gcp"

  domain_name = var.domain_name
  password = var.password

  network_prefixes = ["10.0.0", "10.1.0"]
  network_mask = 16
  network_ranges = [
    for prefix in local.network_prefixes:
    "${prefix}.0/${local.network_mask}"
  ]

  enable_cluster = var.enable_cluster
  enable_hdd = var.enable_hdd
  node_count = var.node_count

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
  domain_name = local.domain_name
  password = local.password
  depends_on = [module.nat]
}

module "sofs" {
  source = "../../modules/sofs"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  domain_name = local.domain_name
  password = local.password
  depends_on = [module.ad]

  node_count = local.node_count
  enable_hdd = local.enable_hdd
  enable_cluster = local.enable_cluster
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
  domain_name = local.domain_name
  enable_domain = true
  depends_on = [module.ad]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  network = google_compute_network.network.name
  enable_ssh = false
}

resource "google_compute_network" "network" {
  name = local.sample_name
  auto_create_subnetworks = false
  depends_on = [module.apis]
}

resource "google_compute_subnetwork" "subnetworks" {
  count = length(local.regions)
  region = local.regions[count.index]
  name = local.regions[count.index]
  ip_cidr_range = local.network_ranges[count.index]
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_all_internal" {
  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    for range in local.network_ranges:
    range
  ]
}
