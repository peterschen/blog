locals {
  org_id = var.org_id
  billing_account = var.billing_account
  project_id = var.project_id
  prefix = var.prefix
  region = var.region
  zones = var.zones

  domain_name = var.domain_name
  password = var.password

  machine_type_bastion = var.machine_type_bastion
  machine_type_sql = var.machine_type_sql

  visible_cores_sql = var.visible_cores_sql
  threads_per_core_sql = var.threads_per_core_sql
  turbo_mode_sql = var.turbo_mode_sql
}

module "demo" {
  source = "../demo"

  org_id = local.org_id
  billing_account = local.billing_account
  project_id = local.project_id
  prefix = local.prefix

  region = local.region
  zones = local.zones

  domain_name = local.domain_name
  password = local.password

  enable_bastion = true
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-64"
  machine_type_sql = "c4-highcpu-96"
  threads_per_core_sql = local.threads_per_core_sql
  visible_cores_sql = local.visible_cores_sql
  turbo_mode_sql = local.turbo_mode_sql

  customization_bastion = file("${path.module}/customization-bastion.ps1")
  customizations_sql = [
    file("${path.module}/customization-sql-0.ps1")
  ]

  modules_dsc_bastion = [
    {
      Name = "SqlServer"
      Version = "22.4.5.1"
    }
  ]
}

data "google_compute_network" "bm" {
  project = module.demo.project_id
  name = module.demo.network_name
  depends_on = [ module.demo ]
}

resource "google_compute_disk" "bm_data" {
  count = 2
  project = module.demo.project_id
  zone = local.zones[0]
  name = "data-${count.index}"
  type = "hyperdisk-extreme"
  size = 500
  provisioned_iops = 175000
}

resource "google_compute_attached_disk" "bm_data" {
  for_each = {
    for entry in flatten([
      for instance in nonsensitive(module.demo.instances): [
          for disk in google_compute_disk.bm_data: {
              instance = instance
              disk = disk
          }
      ]
    ]): "${entry.instance.name}.${entry.disk.name}" => entry
  }

  project = module.demo.project_id
  disk = each.value.disk.id
  instance = each.value.instance.id
  device_name = each.value.disk.name
}

resource "google_monitoring_dashboard" "bm_dashboard" {
  project = module.demo.project_id
  dashboard_json = templatefile("${path.module}/dashboard.json",  {
    project_id = module.demo.project_id
  })
}
