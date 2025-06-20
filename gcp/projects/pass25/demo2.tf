module "demo2" {
  count  = local.enable_demo2 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo2
  prefix = "passdemo2"

  region = local.region_demo2
  zones = [
    local.zone_demo2,
    local.zone_secondary_demo2
  ]

  domain_name = local.domain_name
  password = var.password
  enable_cluster = true
  enable_iam = false

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "n4-standard-4"

  configuration_customization = [
    file("${path.module}/demo2_customization-sql-0.ps1"),
    file("${path.module}/demo2_customization-sql-1.ps1"),
  ]
}

resource "google_compute_disk" "demo2_data" {
  provider = google-beta
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[0].project_id
  zone = local.zone_demo2
  name = "data"
  type = "hyperdisk-balanced"
  access_mode = "READ_WRITE_MANY"
  size = 100
  provisioned_iops = 3000
  provisioned_throughput = 140
}

# resource "google_compute_region_disk" "demo2_quorum" {
#   provider = google-beta
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   region = local.region_demo2
#   replica_zones = [
#     local.zone_demo2,
#     # local.zone_secondary_demo2
#     "europe-west4-b"
#   ]
#   name = "quorum"
#   type = "hyperdisk-balanced-high-availability"
#   size = 4
#   access_mode = "READ_WRITE_MANY"
#   provisioned_iops = 2000
#   provisioned_throughput = 140
# }

resource "google_compute_attached_disk" "demo2_data" {
  for_each = {
    for entry in flatten([
      for module in module.demo2: [
        for instance in module.instances: instance
      ]
    ]): "${entry.name}" => entry
  }

  project = module.demo2[0].project_id
  disk = google_compute_disk.demo2_data[0].id
  instance = each.value.id
  device_name = google_compute_disk.demo2_data[0].name
}

# resource "google_compute_attached_disk" "demo2_quorum" {
#   for_each = {
#     for entry in flatten([
#       for module in module.demo2: [
#         for instance in module.instances: instance
#       ]
#     ]): "${entry.name}" => entry
#   }

#   project = module.demo2[0].project_id
#   disk = google_compute_region_disk.demo2_quorum[0].id
#   instance = each.value.id
#   device_name = google_compute_region_disk.demo2_quorum[0].name
# }

data "google_compute_default_service_account" "default_demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[0].project_id
}

resource "google_project_iam_member" "network_viewer" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[0].project_id
  role = "roles/compute.networkViewer"
  member = "serviceAccount:${data.google_compute_default_service_account.default_demo2[0].email}"
}
