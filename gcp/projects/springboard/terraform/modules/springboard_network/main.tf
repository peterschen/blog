locals {
  project_name = var.project_name
  name = var.name != null ? var.name : replace(local.project_name, "-", "")
  peer_networks = var.peer_networks
  shared_networks = var.shared_networks
}

resource "google_compute_network" "network" {
  project = local.project_name
  name = local.project_name

  auto_create_subnetworks = false
}

resource "google_compute_network_peering" "peer_network" {
  count = length(local.peer_networks)
  name = "${google_compute_network.network.name} to ${local.peer_networks[count.index]}"
  network = google_compute_network.network.name
  peer_network = local.peer_networks[count.index]

  import_custom_routes = true
  stack_type = "IPV4_IPV6"
}
