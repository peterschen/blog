locals {
  project_id = var.project_id
  prefix = var.prefix
  region = var.region
  zones = var.zones
  sample_name = "sqlserver-fci-pd"
  
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
}

module "project" {
  count = local.project_id != null ? 0 : 1
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "compute.googleapis.com",
    "dns.googleapis.com"
  ]
}

data "google_project" "project" {
  project_id = local.project_id != null ? local.project_id : module.project[0].id
}

data "google_compute_default_service_account" "default" {
  project = data.google_project.project.project_id
}

resource "google_compute_network" "network" {
  project = data.google_project.project.project_id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = data.google_project.project.project_id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network.id
  private_ip_google_access = true
}

module "nat" {
  source = "../../modules/nat"
  project = data.google_project.project.project_id

  region = local.region
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "ad" {
  source = "../../modules/ad"
  project = data.google_project.project.project_id

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
  project = data.google_project.project.project_id

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

  configuration_customization = file("${path.module}/customization-bastion.ps1")

  depends_on = [
    module.nat
  ]
}

module "sqlserver" {
  source = "../../modules/sqlserver"
  project = data.google_project.project.project_id
  region = local.region
  zones = local.zones
  
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name
  
  domain_name = local.domain_name
  password = local.password
  
  windows_image = local.sql_image
  machine_type = local.machine_type_sql

  use_developer_edition = local.use_developer_edition
  
  enable_cluster = true

  configuration_customization = [
    file("${path.module}/customization-sql-0.ps1"),
    file("${path.module}/customization-sql-1.ps1"),
  ]

  depends_on = [
    module.nat
  ]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = data.google_project.project.project_id
  network = google_compute_network.network.name
  enable_ssh = false
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  project = data.google_project.project.project_id

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
  project = data.google_project.project.project_id
  zone = local.zones[0]
  name = "data"
  type = "pd-ssd"
  multi_writer = true
  size = 100
}

resource "google_compute_attached_disk" "data" {
  for_each = {
    for entry in flatten([
      for instance in module.sqlserver.instances: instance
    ]): "${entry.name}" => entry
  }

  project = data.google_project.project.project_id
  disk = google_compute_disk.data.id
  instance = each.value.id
  device_name = google_compute_disk.data.name
}