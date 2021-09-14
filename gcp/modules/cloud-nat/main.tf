locals {
  project = var.project
  region = var.region
  network = var.network
}

data "google_compute_network" "network" {
  project = local.project
  name = local.network
}

resource "google_compute_router" "router" {
  project = local.project
  region = local.region
  name = "router"
  network = data.google_compute_network.network.self_link
}

resource "google_compute_router_nat" "nat" {
  project = local.project
  region = local.region
  name = "nat"
  router = google_compute_router.router.name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
