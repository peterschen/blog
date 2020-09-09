provider "google" {
  version = "~> 3.1"
  project = var.project
}

provider "google-beta" {
  version = "~> 3.1"
  project = var.project
}

locals {
  project = var.project
  regions = var.regions
  zones = var.zones
  name-sample = "ad-on-gce"
  name-domain = var.domain-name
  password = var.password
  apis = ["compute.googleapis.com"]
  network-prefixes = ["10.0.0", "10.1.0"]
  network-mask = 16
  network-ranges = ["${local.network-prefixes[0]}.0/${local.network-mask}", "${local.network-prefixes[1]}.0/${local.network-mask}"]
  ip-dcs = ["${local.network-prefixes[0]}.2", "${local.network-prefixes[1]}.2"]
}

module "ad" {
  source = "github.com/peterschen/blog//gcp/modules/activedirectory"
  project = local.project
  regions = ["europe-west4", "europe-west1"]
  zones = ["europe-west4-a", "europe-west1-b"]
  network = google_compute_network.network
  subnetworks = google_compute_subnetwork.subnets
  name-domain = local.name-domain
  password = local.password
}

module "bastion" {
  source = "github.com/peterschen/blog//gcp/modules/bastion-windows"
  project = local.project
  zone = local.zones[0]
  network = google_compute_network.network.self_link
  subnetwork = google_compute_subnetwork.subnets[0].self_link
  machine-name = "bastion"
  password = local.password
  domain-name = local.name-domain
  enable-domain = true
}

module "firewall-iap" {
  source = "github.com/peterschen/blog//gcp/modules/firewall-iap"
  project = local.project
  network = google_compute_network.network
  enable-ssh = false
}

resource "google_project_service" "apis" {
  count = length(local.apis)
  service = local.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnets" {
  count = length(local.regions)
  region = local.regions[count.index]
  name = local.regions[count.index]
  ip_cidr_range = local.network-ranges[count.index]
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  count = length(local.regions)
  region = local.regions[count.index]
  name = "router-${local.regions[count.index]}"
  network = google_compute_network.network.self_link
}

resource "google_compute_router_nat" "nat" {
  count = length(local.regions)
  region = local.regions[count.index]
  name = "nat"
  router = google_compute_router.router[count.index].name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [local.network-ranges[0], local.network-ranges[1]]
}
