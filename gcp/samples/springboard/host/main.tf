provider "google" {
}

locals {
  project_name = var.project_name
  project_prefix = var.project_prefix
  project_suffix = var.project_suffix

  subnets = var.subnets
  peer_networks = var.peer_networks
  enable_peering = var.enable_peering
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  name = local.project_name
  prefix = local.project_prefix
  suffix = local.project_suffix

  apis = [
    "compute.googleapis.com"
  ]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = module.project.id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  count = length(local.subnets)
  project = module.project.id
  region = local.subnets[count.index].region
  name = local.subnets[count.index].name
  ip_cidr_range = local.subnets[count.index].range
  network = google_compute_network.network.name
  private_ip_google_access = local.subnets[count.index].private_ipv4_google_access
  private_ipv6_google_access = local.subnets[count.index].private_ipv6_google_access
}

resource "google_compute_network_peering" "peer_network" {
  count = local.enable_peering ? length(local.peer_networks) : 0
  name = basename(local.peer_networks[count.index])
  network = google_compute_network.network.self_link
  peer_network = local.peer_networks[count.index]

  import_custom_routes = true
  stack_type = "IPV4_IPV6"
}

module "nat" {
  source = "../../modules/nat"
  project = module.project.id

  region = "europe-west4"
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}
