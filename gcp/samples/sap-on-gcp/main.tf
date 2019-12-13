provider "google" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
}

provider "google-beta" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
}

locals {
  name-sample = "sap-on-gce"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
  network-names = ["dmz", "sap"]
  network-prefixes = ["10.128.0.0", "10.132.0.0"]
  network-mask = "20"
  network-ranges = ["${local.network-prefixes[0]}/${local.network-mask}", "${local.network-prefixes[1]}/${local.network-mask}"]
}

data "google_client_config" "current" {}

resource "google_project_service" "apis" {
  count = length(local.apis)
  
  service = "${local.apis[count.index]}"
  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_compute_network" "network" {
  name = "${local.name-sample}"
  auto_create_subnetworks = false

  depends_on = ["google_project_service.apis"]
}

resource "google_compute_subnetwork" "subnets" {
  count = length(local.network-names)
  name = local.network-names[count.index]
  ip_cidr_range = local.network-ranges[count.index]
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.network.self_link
}

resource "google_compute_router_nat" "nat" {
  name = "router-nat"
  router = google_compute_router.router.name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow-all-internal-sap" {
  name    = "allow-all-internal-sap"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [local.network-ranges[1]]
  target_tags = ["sap"]
}

resource "google_compute_firewall" "allow-rdp-gcp" {
  name    = "allow-rdp-gcp"
  network = google_compute_network.network.name
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["rdp"]
}

resource "google_compute_firewall" "allow-ssh-gcp" {
  name    = "allow-ssh-gcp"
  network = google_compute_network.network.name
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["ssh"]
}
