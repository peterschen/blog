provider "google" {
  version = "~> 3.4"
  region = var.region
}

locals {
  project = var.project
  region = var.region
  network = var.network
}

resource "google_compute_router" "router" {
  name = "router"
  network = local.network
}

resource "google_compute_router_nat" "nat" {
  name = "nat"
  router = google_compute_router.router.name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
