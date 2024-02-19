provider "google" {
}

locals {
  name = var.name
  prefix = var.prefix

  peer_networks = var.peer_networks
  shared_networks = var.shared_networks
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  name = local.name
  prefix = local.prefix

  apis = [
    "compute.googleapis.com"
  ]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = module.project.id
  auto_create_subnetworks = false
}

resource "google_compute_network_peering" "peer_network" {
  count = length(local.peer_networks)
  name = basename(local.peer_networks[count.index])
  network = google_compute_network.network.self_link
  peer_network = local.peer_networks[count.index]

  import_custom_routes = true
  stack_type = "IPV4_IPV6"
}
