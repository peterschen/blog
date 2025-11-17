module "demo3" {
  count = local.enable_demo3 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo3
  prefix = "passdemo3"

  region = local.region_demo3
  zones = [
    local.zone_demo3
  ]

  domain_name = local.domain_name
  password = var.password

  enable_bastion = false
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "n4-highcpu-4"

  customizations_sql = [
    file("${path.module}/demo3_customization-sql-0.ps1"),
  ]
}

data "google_compute_network" "demo3" {
  count  = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = module.demo3[count.index].network_name
}

data "google_compute_subnetwork" "demo3" {
  count  = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  region = local.region_demo3
  name = local.region_demo3
}

resource "google_compute_subnetwork" "demo3_secondary" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  region = local.region_secondary_demo3
  name = local.region_secondary_demo3
  ip_cidr_range = "10.1.0.0/16"
  network = module.demo3[count.index].network_id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "demo3_proxy" {
  count  = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  region = local.region_demo3
  name = "${local.region_demo3}-proxy"
  ip_cidr_range = "10.3.0.0/24"
  network = data.google_compute_network.demo3[count.index].id
  purpose = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}

resource "google_compute_subnetwork" "demo3_secondary_proxy" {
  count  = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  region = local.region_secondary_demo3
  name = "${local.region_secondary_demo3}-proxy"
  ip_cidr_range = "10.4.0.0/24"
  network = data.google_compute_network.demo3[count.index].id
  purpose = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}

module "demo3_nat" {
  count = local.enable_demo3 ? 1 : 0
  source = "../../modules/nat"
  project = module.demo3[count.index].project_id
  region = local.region_secondary_demo3
  network = data.google_compute_network.demo3[count.index].name

  depends_on = [
    module.demo3[0]
  ]
}

resource "google_compute_firewall" "demo_3_allow-all-internal" {
  count = local.enable_demo3 ? 1 :0
  project = module.demo3[count.index].project_id
  network = data.google_compute_network.demo3[count.index].name
  name = "allow-all-internal-demo3"
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.demo3_secondary[count.index].ip_cidr_range
  ]
}

module "sqlserver_demo3" {
  count = local.enable_demo3 ? 1 : 0
  source = "../../modules/sqlserver"
  project = module.demo3[count.index].project_id
  region = local.region_secondary_demo3
  zones = [
    local.zone_secondary_demo3
  ]

  network = module.demo3[count.index].network_name
  subnetwork = google_compute_subnetwork.demo3_secondary[count.index].name
  
  domain_name = local.domain_name
  password = var.password
  
  machine_prefix = "sql-recovery"
  machine_type = "n4-highcpu-4"

  # Firewall configuration already made by other sqlserver deployment
  enable_firewall = false
  enable_cluster = false

  depends_on = [
    google_compute_subnetwork.demo3_secondary
  ]
}

resource "google_compute_resource_policy" "demo3_group" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = "sql"
  region = local.region_demo3

  disk_consistency_group_policy {
    enabled = true
  }
}

resource "google_compute_resource_policy" "demo3_secondary_group" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = "sql"
  region = local.region_secondary_demo3

  disk_consistency_group_policy {
    enabled = true
  }
}

resource "google_compute_disk" "demo3_data" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_demo3
  name = "data"
  type = "hyperdisk-balanced"
  size = 50
}

resource "google_compute_disk" "demo3_log" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_demo3
  name = "log"
  type = "hyperdisk-balanced"
  size = 25
}

resource "google_compute_disk" "demo3_secondary_data" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_secondary_demo3
  name = "data"
  type = "hyperdisk-balanced"
  size = 50

  async_primary_disk {
    disk = google_compute_disk.demo3_data[count.index].id
  }
}

resource "google_compute_disk" "demo3_secondary_log" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_secondary_demo3
  name = "log"
  type = "hyperdisk-balanced"
  size = 25

  async_primary_disk {
    disk = google_compute_disk.demo3_log[count.index].id
  }
}

resource "google_compute_disk_resource_policy_attachment" "demo3_data" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = google_compute_resource_policy.demo3_group[count.index].name
  disk = google_compute_disk.demo3_data[count.index].name
  zone = google_compute_disk.demo3_data[count.index].zone
}

resource "google_compute_disk_resource_policy_attachment" "demo3_log" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = google_compute_resource_policy.demo3_group[count.index].name
  disk = google_compute_disk.demo3_log[count.index].name
  zone = google_compute_disk.demo3_log[count.index].zone
}

resource "google_compute_disk_resource_policy_attachment" "demo3_secondary_data" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = google_compute_resource_policy.demo3_secondary_group[count.index].name
  disk = google_compute_disk.demo3_secondary_data[count.index].name
  zone = google_compute_disk.demo3_secondary_data[count.index].zone
}

resource "google_compute_disk_resource_policy_attachment" "demo3_secondary_log" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  name = google_compute_resource_policy.demo3_secondary_group[count.index].name
  disk = google_compute_disk.demo3_secondary_log[count.index].name
  zone = google_compute_disk.demo3_secondary_log[count.index].zone
}

resource "google_compute_disk_async_replication" "demo3_data" {
  count = local.enable_demo3 ? 1 : 0
  primary_disk = google_compute_disk.demo3_data[count.index].id
  secondary_disk {
    disk  = google_compute_disk.demo3_secondary_data[count.index].id
  }

  depends_on = [
    google_compute_disk.demo3_data[0],
    google_compute_disk.demo3_secondary_data[0],
    google_compute_disk_resource_policy_attachment.demo3_data[0]
  ]
}

resource "google_compute_disk_async_replication" "demo3_log" {
  count = local.enable_demo3 ? 1 : 0
  primary_disk = google_compute_disk.demo3_log[count.index].id
  secondary_disk {
    disk  = google_compute_disk.demo3_secondary_log[count.index].id
  }

  depends_on = [ 
    google_compute_disk.demo3_log[0],
    google_compute_disk.demo3_secondary_log[0],
    google_compute_disk_resource_policy_attachment.demo3_log[0]
  ]
}

resource "google_compute_attached_disk" "demo3_data" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  disk = google_compute_disk.demo3_data[count.index].id
  instance = module.demo3[count.index].instances[0].id
  device_name = google_compute_disk.demo3_data[count.index].name
}

resource "google_compute_attached_disk" "demo3_log" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  disk = google_compute_disk.demo3_log[count.index].id
  instance = module.demo3[count.index].instances[0].id
  device_name = google_compute_disk.demo3_log[count.index].name
}

resource "google_monitoring_dashboard" "demo3_dashboard" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  dashboard_json = file("${path.module}/demo3_dashboard.json")
}

resource "google_compute_firewall" "demo3_healthcheck" {
  count  = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "allow-mssql-healthcheck"
  network = data.google_compute_network.demo3[count.index].self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  target_tags = ["mssql"]
}

resource "google_compute_firewall" "demo3_loadbalancer" {
  count  = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "allow-mssql-loadbalancer"
  network = data.google_compute_network.demo3[count.index].self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }

  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.demo3_proxy[count.index].ip_cidr_range,
    google_compute_subnetwork.demo3_secondary_proxy[count.index].ip_cidr_range
  ]
  target_tags = ["mssql"]
}

resource "google_compute_health_check" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "sql"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  tcp_health_check {
    port = 1433
  }
}

resource "google_compute_network_endpoint_group" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_demo3

  name = "sql"
  network_endpoint_type = "GCE_VM_IP_PORT"
  network = data.google_compute_network.demo3[count.index].self_link
  subnetwork = data.google_compute_subnetwork.demo3[count.index].self_link
}

resource "google_compute_network_endpoint_group" "demo3_secondary" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_secondary_demo3

  name = "sql"
  network_endpoint_type = "GCE_VM_IP_PORT"
  network = data.google_compute_network.demo3[count.index].self_link
  subnetwork = google_compute_subnetwork.demo3_secondary[count.index].self_link
}

data "google_compute_address" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  region = local.region_demo3
  name = "sql-0"

  depends_on = [ 
    module.demo3
  ]
}

data "google_compute_address" "demo3_secondary" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  region = local.region_secondary_demo3
  name = "sql-recovery-0"

  depends_on = [ 
    module.sqlserver_demo3
  ]
}

resource "google_compute_network_endpoint" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_demo3
  
  network_endpoint_group = google_compute_network_endpoint_group.demo3[count.index].id
  instance = one(module.demo3[count.index].instances).name
  ip_address = data.google_compute_address.demo3[count.index].address
  port = 1433
}

resource "google_compute_network_endpoint" "demo3_secondary" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id
  zone = local.zone_secondary_demo3
  
  network_endpoint_group = google_compute_network_endpoint_group.demo3_secondary[count.index].id
  instance = one(module.sqlserver_demo3[count.index].instances).name
  ip_address = data.google_compute_address.demo3_secondary[count.index].address
  port = 1433
}

resource "google_compute_backend_service" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "sql"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address_selection_policy = "IPV4_ONLY"
  protocol = "TCP"
  port_name = "mssql"

  timeout_sec = 1
  connection_draining_timeout_sec = 1

  health_checks = [
    google_compute_health_check.demo3[count.index].id
  ]
  
  dynamic "backend" {
    for_each = google_compute_network_endpoint_group.demo3
    content {
      balancing_mode = "CONNECTION"
      capacity_scaler = 1
      group = backend.value.id
      max_connections_per_endpoint = 10000
    }
  }

  dynamic "backend" {
    for_each = google_compute_network_endpoint_group.demo3_secondary
    content {
      balancing_mode = "CONNECTION"
      capacity_scaler = 0
      group = backend.value.id
      max_connections_per_endpoint = 10000
   }
  }

  log_config {
    enable = true
    optional_mode = "INCLUDE_ALL_OPTIONAL"
  }
}

resource "google_compute_target_tcp_proxy" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "sql"
  backend_service = google_compute_backend_service.demo3[count.index].id
}

resource "google_compute_global_address" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "sql"
  address_type = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "demo3" {
  count = local.enable_demo3 ? 1 : 0
  project = module.demo3[count.index].project_id

  name = "sql"
  ip_address = google_compute_global_address.demo3[count.index].address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol = "TCP"
  port_range = "1433-1433"
  target = google_compute_target_tcp_proxy.demo3[count.index].id

  depends_on = [
    google_compute_subnetwork.demo3_proxy
  ]
}