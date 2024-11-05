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
  machine_type_sql = "n2-standard-4"
  # machine_type_sql = "m3-ultramem-32"

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
  type = "pd-ssd"
  multi_writer = true
  # type = "hyperdisk-balanced"
  # access_mode = "READ_WRITE_MANY"
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

# data "google_compute_network" "network" {
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   name = module.demo2[0].network_name
# }

# data "google_compute_subnetwork" "subnetwork" {
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   region = local.region_demo2
#   name = local.region_demo2
# }

# resource "google_compute_address" "sql_demo2" {
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   region = local.region_demo2
#   name = "sql"
#   address_type = "INTERNAL"
#   purpose = "SHARED_LOADBALANCER_VIP"
#   subnetwork = data.google_compute_subnetwork.subnetwork[0].id
# }

# # resource "google_compute_instance_group" "sql_demo2" {
# #   count = local.enable_demo2 ? length(module.demo2[0].instances) : 0
# #   project = module.demo2[0].project_id
# #   zone = [
# #     local.zone_demo2,
# #     local.zone_secondary_demo2
# #   ][count.index]
# #   name = "sql-demo2-${count.index}"
# #   instances = [module.demo2[0].instances[count.index].id]
# #   network = data.google_compute_network.network[0].id
# # }

# data "google_compute_instance_group" "sql" {
#   count = local.enable_demo2 ? length(module.demo2[0].instances) : 0
#   project = module.demo2[0].project_id
#    zone = [
#     local.zone_demo2,
#     local.zone_secondary_demo2
#   ][count.index]
#   name = "sql-${count.index}"
# }

# resource "google_compute_health_check" "sql_demo2" {
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   name = "sql-demo2"
#   timeout_sec = 1
#   check_interval_sec = 2

#   tcp_health_check {
#     port = 59998
#     request = google_compute_address.sql_demo2[count.index].address
#     response = "1"
#   }
# }

# resource "google_compute_region_backend_service" "sql_demo2" {
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   region = local.region_demo2
#   name = "sql-demo2"
#   health_checks = [
#     google_compute_health_check.sql_demo2[count.index].id
#   ]
#   protocol = "UNSPECIFIED"

#   dynamic "backend" {
#     for_each = data.google_compute_instance_group.sql
#     content {
#       group = backend.value.id
#     }
#   }
# }

# resource "google_compute_forwarding_rule" "sql" {
#   count = local.enable_demo2 ? 1 : 0
#   project = module.demo2[0].project_id
#   region = local.region_demo2
#   name = "sql-demo2"
#   ip_address = google_compute_address.sql_demo2[count.index].address
#   load_balancing_scheme = "INTERNAL"
#   ip_protocol = "L3_DEFAULT"
#   all_ports = true
#   allow_global_access = true
#   network = data.google_compute_network.network[0].id
#   subnetwork = data.google_compute_subnetwork.subnetwork[0].id
#   backend_service = google_compute_region_backend_service.sql_demo2[count.index].id
# }
