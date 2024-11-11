locals {
  prefix = var.prefix
  region = var.region
  zones = var.zones
  sample_name = "sqlserver-on-gcp"
  
  domain_name = var.domain_name
  password = var.password

  windows_image = var.windows_image
  windows_core_image = var.windows_core_image
  sql_image = var.sql_image

  network_range = "10.0.0.0/16"

  machine_type_dc = var.machine_type_dc
  machine_type_bastion = var.machine_type_bastion
  machine_type_sql = var.machine_type_sql

  use_developer_edition = var.use_developer_edition

  enable_cluster = var.enable_cluster
  enable_alwayson = var.enable_alwayson
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "compute.googleapis.com",
    "dns.googleapis.com"
  ]
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = module.project.id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network.id
  private_ip_google_access = true
}

module "nat" {
  source = "../../modules/nat"
  project = module.project.id

  region = local.region
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "ad" {
  source = "../../modules/ad"
  project = module.project.id

  regions = [local.region]
  zones = local.zones

  network = google_compute_network.network.name
  subnetworks = [
    google_compute_subnetwork.subnetwork.name
  ]

  domain_name = local.domain_name
  machine_type = local.machine_type_dc

  windows_image = local.windows_core_image

  password = local.password
  enable_ssl = false

  depends_on = [
    module.nat
  ]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  project = module.project.id

  region = local.region
  zone = local.zones[0]

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  machine_type = local.machine_type_bastion
  machine_name = "bastion"

  windows_image = local.windows_image

  domain_name = local.domain_name
  password = local.password

  enable_domain = true
  enable_discoveryclient = false
  enable_ssms = true

  depends_on = [
    module.ad
  ]
}

module "sqlserver" {
  source = "../../modules/sqlserver"
  project = module.project.id
  region = local.region
  zones = local.zones
  
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name
  
  domain_name = local.domain_name
  password = local.password
  
  windows_image = local.sql_image
  machine_type = local.machine_type_sql

  use_developer_edition = local.use_developer_edition

  enable_cluster = local.enable_cluster
  enable_alwayson = local.enable_alwayson

  configuration_customization_sql = [
    file("${path.module}/customization-sql-0.ps1"),
    file("${path.module}/customization-sql-1.ps1"),
  ]

  depends_on = [module.ad]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
  enable_ssh = false
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  project = module.project.id

  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range
  ]
}

resource "google_compute_disk" "data" {
  provider = google-beta
  count = local.enable_cluster ? 1 : 0
  project = module.project.id
  zone = local.zones[0]
  name = "data"
  type = "pd-ssd"
  multi_writer = true
  size = 100
}

resource "google_compute_attached_disk" "data" {
  for_each = {
    for entry in flatten([
      for disk in google_compute_disk.data: [
        for instance in module.sqlserver.instances:  {
            instance = instance
            disk = disk
        }
      ]
    ]): "${entry.instance.name}.${entry.disk.name}" => entry
  }

  project = module.project.id
  disk = each.value.disk.id
  instance = each.value.instance.id
  device_name = each.value.disk.name
}
