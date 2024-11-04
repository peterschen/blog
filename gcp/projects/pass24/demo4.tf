module "demo4" {
  count = local.enable_demo4 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo4
  prefix = "passdemo4"

  region = local.region_demo4
  zones = [
    local.zone_demo4
  ]

  domain_name = local.domain_name
  password = var.password
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-64"
  machine_type_sql = "c4-highcpu-192"
}

resource "google_compute_disk" "demo4_data" {
  count = local.enable_demo4 ? 2 : 0
  project = module.demo4[0].project_id
  zone = local.zone_demo4
  name = "data-${count.index}"
  type = "hyperdisk-extreme"
  size = 500
  provisioned_iops = 250000
}

resource "google_compute_attached_disk" "demo4_data" {
  for_each = {
    for entry in flatten([
      for module in module.demo4: [
        for instance in module.instances: [
            for disk in google_compute_disk.demo4_data: {
                instance = instance
                disk = disk
            }
        ]
      ]
    ]): "${entry.instance.name}.${entry.disk.name}" => entry
  }

  project = module.demo4[0].project_id
  disk = each.value.disk.id
  instance = each.value.instance.id
  device_name = each.value.disk.name
}

resource "google_monitoring_dashboard" "demo4_dashboard" {
  count = local.enable_demo4 ? 1 : 0
  project = module.demo4[count.index].project_id
  dashboard_json = templatefile("${path.module}/demo4_dashboard.json",  {
    project_id = module.demo4[count.index].project_id
  })
}
