locals {
  region = var.region
  network = var.network
}

data "google_compute_network" "network" {
  name = local.network
}

resource "google_compute_router" "router" {
  region = local.region
  name = "router"
  network = data.google_compute_network.network.self_link

resource "google_compute_router_nat" "nat" {
  region = local.region
  name = "nat"
  router = google_compute_router.router.name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
