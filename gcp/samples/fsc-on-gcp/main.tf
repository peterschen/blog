terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
}

locals {
  ad_zones = var.ad_zones
  cluster_zones = var.cluster_zones
  witness_zone = var.witness_zone
  bastion_zone = var.bastion_zone

  regions = distinct([
    for zone in concat(local.ad_zones, local.cluster_zones, [local.witness_zone, local.bastion_zone]):
    substr(zone, 0, length(zone) - 2)
  ])

  ad_regions = [
    for zone in local.ad_zones:
    substr(zone, 0, length(zone) - 2)
  ]
  
  cluster_region = element([
    for zone in local.cluster_zones:
    substr(zone, 0, length(zone) - 2)
  ], 1)

  witness_region = substr(local.witness_zone, 0, length(local.witness_zone) - 2)
  bastion_region = substr(local.bastion_zone, 0, length(local.bastion_zone) - 2)

  network_name = "fsc-on-gcp"
  network_prefixes = [
    for i in range(length(local.regions)):
    "10.${i}.0"
  ]
  network_mask = 16
  network_ranges = [
    for prefix in local.network_prefixes:
    "${prefix}.0/${local.network_mask}"
  ]

  domain_name = var.domain_name
  password = var.password
  
  windows_image_dc = var.windows_image_dc
  windows_image_bastion = var.windows_image_bastion
  windows_image_witness = var.windows_image_witness
  windows_image_cluster = var.windows_image_cluster

  enable_cluster = var.enable_cluster
  enable_distributednodename = var.enable_distributednodename
  enable_storagespaces = var.enable_storagespaces
  node_count = var.node_count

  cache_disk_count = var.cache_disk_count
  cache_disk_interface = var.cache_disk_interface
  capacity_disk_count = var.capacity_disk_count
  capacity_disk_type = var.capacity_disk_type
  capacity_disk_size = var.capacity_disk_size
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  apis = [
    "compute.googleapis.com"
  ]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = local.network_name
  auto_create_subnetworks = false

  depends_on = [
    module.project
  ]
}

resource "google_compute_subnetwork" "subnet" {
  count = length(local.regions)
  project = module.project.id
  region = local.regions[count.index]
  name = local.regions[count.index]

  ip_cidr_range = local.network_ranges[count.index]
  network = google_compute_network.network.id
  private_ip_google_access = true
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
}

resource "google_compute_firewall" "allow_all_internal" {
  project = module.project.id

  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = local.network_ranges
}

module "nat" {
  source = "../../modules/nat"
  count = length(local.regions)
  project = module.project.id
  region = local.regions[count.index]
  network = google_compute_network.network.name
  
  depends_on = [
    google_compute_network.network
  ]
}

module "ad" {
  source = "../../modules/ad"
  
  project = module.project.id
  
  regions = local.ad_regions
  zones = local.ad_zones

  network = google_compute_network.network.name

  subnetworks = [
    for subnet in google_compute_subnetwork.subnet:
    subnet.name if contains(local.ad_regions, subnet.region)
  ]

  windows_image = local.windows_image_dc

  domain_name = local.domain_name
  password = local.password

  depends_on = [
    module.nat
  ]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  
  project = module.project.id
  region = local.bastion_region
  zone = local.bastion_zone
  network = google_compute_network.network.name

  subnetwork = element([
    for subnet in google_compute_subnetwork.subnet:
    subnet.name if local.bastion_region == subnet.region
  ], 1)
  
  machine_name = "bastion"
  windows_image = local.windows_image_bastion

  domain_name = local.domain_name
  password = local.password
  
  enable_domain = true

  depends_on = [
    module.ad
  ]
}

module "fsc" {
  source = "../../modules/fsc"

  project = module.project.id
  # TODO Christoph: Witness could potentially be in a different region
  region = local.cluster_region
  cluster_zones = local.cluster_zones
  witness_zone = local.witness_zone

  network = google_compute_network.network.name
  subnetwork = element([
    for subnet in google_compute_subnetwork.subnet:
    subnet.name if local.cluster_region == subnet.region
  ], 1)

  windows_image_witness = local.windows_image_witness
  windows_image_cluster = local.windows_image_cluster

  domain_name = local.domain_name
  password = local.password

  enable_cluster = local.enable_cluster
  enable_distributednodename = local.enable_distributednodename
  enable_storagespaces = local.enable_storagespaces

  node_count = local.node_count
  cache_disk_count = local.cache_disk_count
  cache_disk_interface = local.cache_disk_interface
  capacity_disk_count = local.capacity_disk_count
  capacity_disk_type = local.capacity_disk_type
  capacity_disk_size = local.capacity_disk_size

  depends_on = [
    module.ad
  ]
}
