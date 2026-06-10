module "demo1" {
  count = local.enable_demo1 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo1
  prefix = "pass1"

  region = local.region_demo1
  zones = [
    local.zone_demo1
  ]

  domain_name = local.domain_name
  password = var.password

  enable_bastion = true
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-64"
  machine_type_sql = "c4-highcpu-192"

  customization_bastion = file("${path.module}/demo1_customization-bastion.ps1")
  customizations_sql = [
    file("${path.module}/demo1_customization-sql-0.ps1")
  ]
}

data "google_compute_network" "demo1" {
  count  = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  name = module.demo1[count.index].network_name

  depends_on = [ module.demo1 ]
}

resource "google_compute_subnetwork" "demo1" {
  count  = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  region = local.region_demo1
  name = "demo1"
  ip_cidr_range = "10.1.0.0/24"
  network = data.google_compute_network.demo1[count.index].id
  purpose = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}

resource "google_compute_firewall" "demo1_healthcheck" {
  count  = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id

  name = "allow-mssql-healthcheck"
  network = data.google_compute_network.demo1[count.index].self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  target_tags = ["mssql"]
}

resource "google_compute_firewall" "demo1_loadbalancer" {
  count  = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id

  name = "allow-mssql-loadbalancer"
  network = data.google_compute_network.demo1[count.index].self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }

  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.demo1[count.index].ip_cidr_range
  ]
  target_tags = ["mssql"]
}

resource "google_compute_instance_group" "demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  zone = local.zone_demo1
  name = "sql"
  
  instances = [
    for instance in module.demo1[count.index].instances:
      instance.self_link
  ]

  named_port {
    name = "mssql"
    port = 1433
  }

  network = data.google_compute_network.demo1[count.index].self_link
}

resource "google_compute_region_health_check" "demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  region = local.region_demo1

  name = "sql"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  tcp_health_check {
    port = 1433
  }
}

resource "google_compute_region_backend_service" "demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  region = local.region_demo1

  name = "sql"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address_selection_policy = "IPV4_ONLY"
  protocol = "TCP"
  port_name = "mssql"

  health_checks = [
    google_compute_region_health_check.demo1[count.index].id
  ]
  
  dynamic "backend" {
    for_each = google_compute_instance_group.demo1
    content {
      balancing_mode = "CONNECTION"
      capacity_scaler = 1
      group = backend.value.id
      max_connections_per_instance = 10000
    }
  }

  # log_config {
  #   enable = true
  #   optional_mode = "INCLUDE_ALL_OPTIONAL"
  # }

  depends_on = [
    google_compute_instance_group.demo1
  ]
}

resource "google_compute_region_target_tcp_proxy" "demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  region = local.region_demo1

  name = "sql"
  backend_service = google_compute_region_backend_service.demo1[count.index].id
}

resource "google_compute_address" "demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  region = local.region_demo1

  name = "sql"
  address_type = "EXTERNAL"
}

resource "google_compute_forwarding_rule" "demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  region = local.region_demo1

  name = "sql"
  ip_address = google_compute_address.demo1[count.index].address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol = "TCP"
  port_range = "1433-1433"
  target = google_compute_region_target_tcp_proxy.demo1[count.index].id
  network = data.google_compute_network.demo1[count.index].id

  depends_on = [
    google_compute_subnetwork.demo1
  ]
}

resource "google_compute_disk" "demo1_data" {
  count = local.enable_demo1 ? 4 : 0
  project = module.demo1[0].project_id
  zone = local.zone_demo1
  name = "data-${count.index}"
  type = "hyperdisk-extreme"
  size = 500
  provisioned_iops = 250000
}

resource "google_compute_attached_disk" "demo1_data" {
  for_each = {
    for entry in flatten([
      for module in module.demo1: [
        for instance in nonsensitive(module.instances): [
            for disk in google_compute_disk.demo1_data: {
                instance = instance
                disk = disk
            }
        ]
      ]
    ]): "${entry.instance.name}.${entry.disk.name}" => entry
  }

  project = module.demo1[0].project_id
  disk = each.value.disk.id
  instance = each.value.instance.id
  device_name = each.value.disk.name
}

resource "google_monitoring_dashboard" "demo1_dashboard" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  dashboard_json = templatefile("${path.module}/demo1_dashboard.json",  {
    project_id = module.demo1[count.index].project_id
  })
}
