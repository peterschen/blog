locals {
  project_id = var.project_id
  prefix = var.prefix
  region = var.region
  zone = var.zone
  sample_name = "smtoff"
  
  domain_name = var.domain_name
  password = var.password

  network_range = "10.0.0.0/16"

  machine_type_dc = "n4-highcpu-2"
  machine_type_bastion = "n4-highcpu-48"
  machine_type_sql = var.machine_type
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
  zones = [local.zone]

  network = google_compute_network.network.name
  subnetworks = [
    google_compute_subnetwork.subnetwork.name
  ]

  domain_name = local.domain_name
  machine_type = local.machine_type_dc

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
  zone = local.zone

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  machine_type = local.machine_type_bastion
  machine_name = "bastion"

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
  zones = [local.zone]
  
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name
  
  domain_name = local.domain_name
  password = local.password
  
  machine_type = local.machine_type_sql
  threads_per_core = 1

  use_developer_edition = true
  enable_cluster = false

  configuration_customization = [
    file("${path.module}/customization-sql-0.ps1"),
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

# resource "google_compute_disk" "data" {
#   project = data.google_project.project.project_id
#   zone = local.zone
#   name = "data"
#   type = "hyperdisk-balanced"
#   size = 350
  
#   # Maximize performance even if the machine doesn't support it
#   provisioned_iops = 160000
#   provisioned_throughput = 2400
# }

# resource "google_compute_attached_disk" "data" {
#   for_each = {
#     for entry in flatten([
#       for instance in module.sqlserver.instances: instance
#     ]): "${entry.name}" => entry
#   }

#   project = data.google_project.project.project_id
#   disk = google_compute_disk.data.id
#   instance = each.value.id
#   device_name = google_compute_disk.data.name
# }

resource "google_project_iam_member" "secret_accessor" {
  project = "cbpetersen-shared"
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "storage_object_user" {
  project = "cbpetersen-shared"
  role = "roles/storage.objectUser"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_compute_instance_iam_member" "instance_admin" {
  count = length(module.sqlserver.instances)
  project = data.google_project.project.project_id
  zone = local.zone
  instance_name = module.sqlserver.instances[count.index].name
  role = "roles/compute.instanceAdmin.v1"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}
