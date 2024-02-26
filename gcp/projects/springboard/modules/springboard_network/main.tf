locals {
  project_name = var.project_name
  name = var.name != null ? var.name : local.project_name
  subnets = var.subnets
  peer_networks = var.peer_networks
  shared_networks = var.shared_networks
}

resource "google_compute_network" "network" {
  project = local.project_name
  name = local.project_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  count = length(local.subnets)
  project = local.project_name
  region = local.subnets[count.index].region
  name = local.subnets[count.index].name
  ip_cidr_range = local.subnets[count.index].range
  network = google_compute_network.network.name
  private_ip_google_access = local.subnets[count.index].private_ipv4_google_access
  private_ipv6_google_access = local.subnets[count.index].private_ipv6_google_access
}

resource "google_compute_network_peering" "peer_network" {
  count = length(local.peer_networks)
  name = basename(local.peer_networks[count.index])
  network = google_compute_network.network.self_link
  peer_network = local.peer_networks[count.index]

  import_custom_routes = true
  stack_type = "IPV4_IPV6"
}
