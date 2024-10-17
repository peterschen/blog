module "demo6" {
  count = local.enable_demo6 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo6
  prefix = "passdemo6"

  region = local.region_demo6
  zones = [
    local.zone_demo6
  ]

  domain_name = local.domain_name
  password = var.password
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-64"
  machine_type_sql = "c4-highcpu-192"
}

resource "google_compute_disk" "demo6_data" {
  count = local.enable_demo6 ? 2 : 0
  project = module.demo6[0].project_id
  zone = local.zone_demo5
  name = "data-${count.index}"
  type = "hyperdisk-extreme"
  size = 500
  provisioned_iops = 500000
}

resource "google_compute_attached_disk" "demo6_data" {
  for_each = {
    for entry in flatten([
      for module in module.demo6: [
        for instance in module.instances: [
            for disk in google_compute_disk.demo6_data: {
                instance = instance
                disk = disk
            }
        ]
      ]
    ]): "${entry.instance.name}.${entry.disk.name}" => entry
  }

  project = module.demo6[0].project_id
  disk = each.value.disk.id
  instance = each.value.instance.id
  device_name = each.value.disk.name
}

resource "google_monitoring_dashboard" "demo6_dashboard" {
  count = local.enable_demo6 ? 1 : 0
  project = module.demo6[count.index].project_id
  dashboard_json = templatefile("${path.module}/demo6_dashboard.json",  {
    project_id = module.demo6[count.index].project_id
  })
}
