locals {
  project_id = var.project_id
  prefix = var.prefix
  region = var.region
  zones = var.zones
  sample_name = "pass25"

  apis = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "osconfig.googleapis.com"
  ]
  
  domain_name = var.domain_name
  password = var.password

  windows_image = var.windows_image
  windows_core_image = var.windows_core_image
  sql_image = var.sql_image

  network_range = "10.0.0.0/16"

  machine_type_dc = "n4-highcpu-2"
  machine_type_bastion = var.machine_type_bastion
  machine_type_sql = var.machine_type_sql

  enable_bastion = var.enable_bastion
  enable_ad = var.enable_ad
  enable_sql = var.enable_sql
  enable_cluster = var.enable_cluster
  enable_alwayson = var.enable_alwayson

  enable_iam = var.enable_iam

  customization_bastion = var.customization_bastion
  customizations_sql = var.customizations_sql
}

module "project" {
  source = "../../../modules/project"

  count = local.project_id != null ? 0 : 1
  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = local.apis
}

data "google_project" "project" {
  project_id = local.project_id != null ? local.project_id : module.project[0].id
}

data "google_compute_default_service_account" "default" {
  project = data.google_project.project.project_id
}

# If the project is created outside of this configuration
# make sure that all necessary APIs are enabled
resource "google_project_service" "apis" {
  count = length(local.apis)
  project = data.google_project.project.project_id
  service = local.apis[count.index]

  disable_dependent_services = true
  disable_on_destroy = false
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

module "firewall_iap" {
  source = "../../../modules/firewall_iap"
  project = data.google_project.project.project_id
  network = google_compute_network.network.name
  enable_rdp = true
  enable_ssh = true
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

module "nat" {
  source = "../../../modules/nat"
  project = data.google_project.project.project_id

  region = local.region
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "ad" {
  count = local.enable_ad ? 1 : 0
  source = "../../../modules/ad"
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
  count = local.enable_bastion ? 1 : 0
  source = "../../../modules/bastion_windows"
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

  enable_domain = local.enable_ad
  enable_ssms = true
  enable_hammerdb = true
  enable_discoveryclient = false

  configuration_customization = local.customization_bastion

  depends_on = [
    module.ad
  ]
}

module "sqlserver" {
  count = local.enable_sql ? 1 : 0
  source = "../../../modules/sqlserver"
  project = data.google_project.project.project_id
  region = local.region
  zones = local.zones
  
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name
  
  domain_name = local.domain_name
  password = local.password
  
  windows_image = local.sql_image
  machine_type = local.machine_type_sql

  configuration_customizations = local.customizations_sql

  enable_cluster = local.enable_cluster
  depends_on = [module.ad]
}

resource "google_project_iam_member" "secret_accessor" {
  project = "cbpetersen-shared"
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "log_writer" {
  count = local.enable_iam ? 1 : 0
  project = data.google_project.project.project_id
  role = "roles/logging.logWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "sql_alert_writer" {
  count = local.enable_iam ? 1 : 0
  project = data.google_project.project.project_id
  role = "roles/logging.sqlAlertWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "metric_writer" {
  count = local.enable_iam ? 1 : 0
  project = data.google_project.project.project_id
  role = "roles/monitoring.metricWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}
