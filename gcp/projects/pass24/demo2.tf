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

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "n2-highcpu-4"
}

resource "google_compute_disk" "demo2_data" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[0].project_id
  zone = local.zone_demo2
  name = "data"
  type = "hyperdisk-balanced"
  access_mode = "READ_WRITE_MANY"
  size = 100
}

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
