terraform {
  required_providers {
    google = {
      version = "~> 5.0"
    }
  }
}

provider "google" {
}

provider "google-beta" {
}

locals {
}

module "demo5" {
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  prefix = "passdemo5"

  zones = [ 
      "europe-west4-a"
  ]

  domain_name = var.domain_name
  password = var.password
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "c4-highcpu-4"
}

module "demo6" {
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  prefix = "passdemo6"

  zones = [ 
      "europe-west4-a"
  ]

  domain_name = var.domain_name
  password = var.password
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-64"
  machine_type_sql = "c4-highcpu-192"
}

resource "google_compute_disk" "demo6_data" {
  count = 2
  project = module.demo6.project_id
  zone = module.demo6.zones[0]
  name = "data-${count.index}"
  type = "hyperdisk-extreme"
  size = 500
  provisioned_iops = 500000
}

resource "google_compute_attached_disk" "demo6_data" {
  for_each = {
    for entry in flatten([
        for instance in module.demo6.instances: [
            for disk in google_compute_disk.demo6_data: {
                instance = instance
                disk = disk
            }
        ]
    ]): "${entry.instance.name}.${entry.disk.name}" => entry
  }

  project = module.demo6.project_id
  disk = each.value.disk.id
  instance = each.value.instance.id
  device_name = each.value.disk.name
}

resource "google_monitoring_dashboard" "demo6_dashboard" {
  project = module.demo6.project_id
  dashboard_json = templatefile("${path.module}/demo6_dashboard.json",  {
    project_id = module.demo6.project_id
  })
}

# resource "google_compute_disk" "data" {
#   count = 2
#   provider = google-beta
#   project = data.google_project.project.project_id
#   region = local.region
#   name = "data-${count.index}"
#   type = "hyperdisk-balanced-high-availability"
#   access_mode = "READ_WRITE_MANY"
# }
