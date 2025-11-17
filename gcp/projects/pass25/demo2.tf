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

  enable_bastion = true
  enable_cluster = true
  enable_quorum = false
  enable_iam = false

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "n4-standard-4"

  customizations_sql = [
    file("${path.module}/demo2_customization-sql-0.ps1"),
    file("${path.module}/demo2_customization-sql-1.ps1"),
  ]
}

data "google_compute_network" "demo2" {
  count  = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  name = module.demo2[count.index].network_name
}

data "google_compute_subnetwork" "demo2" {
  count  = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2
  name = local.region_demo2
}

resource "google_compute_subnetwork" "demo2" {
  count  = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2
  name = "demo2"
  ip_cidr_range = "10.1.0.0/24"
  network = data.google_compute_network.demo2[count.index].id
  purpose = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}

resource "google_compute_firewall" "demo2_healthcheck" {
  count  = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id

  name = "allow-mssql-healthcheck"
  network = data.google_compute_network.demo2[count.index].self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  target_tags = ["mssql"]
}

resource "google_compute_firewall" "demo2_loadbalancer" {
  count  = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id

  name = "allow-mssql-loadbalancer"
  network = data.google_compute_network.demo2[count.index].self_link
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["1433"]
  }

  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.demo2[count.index].ip_cidr_range
  ]
  target_tags = ["mssql"]
}

resource "google_compute_region_health_check" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2

  name = "sql"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  tcp_health_check {
    port = 1433
  }
}

resource "google_compute_network_endpoint_group" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  zone = local.zone_demo2

  name = "sql"
  network_endpoint_type = "NON_GCP_PRIVATE_IP_PORT"
  network = data.google_compute_network.demo2[count.index].self_link
}

data "google_compute_address" "wsfc_sql" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2
  name = "wsfc-sql"
}

resource "google_compute_network_endpoint" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  zone = local.zone_demo2
  network_endpoint_group = google_compute_network_endpoint_group.demo2[count.index].id
  ip_address = data.google_compute_address.wsfc_sql[count.index].address
  port = 1433
}

resource "google_compute_region_backend_service" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2

  name = "sql"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address_selection_policy = "IPV4_ONLY"
  protocol = "TCP"
  port_name = "mssql"

  health_checks = [
    google_compute_region_health_check.demo2[count.index].id
  ]
  
  dynamic "backend" {
    for_each = google_compute_network_endpoint_group.demo2
    content {
      balancing_mode = "CONNECTION"
      capacity_scaler = 1
      group = backend.value.id
      max_connections_per_endpoint = 10000
    }
  }

  log_config {
    enable = true
    optional_mode = "INCLUDE_ALL_OPTIONAL"
  }
}

resource "google_compute_region_target_tcp_proxy" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2

  name = "sql"
  backend_service = google_compute_region_backend_service.demo2[count.index].id
}

resource "google_compute_address" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2

  name = "sql"
  address_type = "EXTERNAL"
}

resource "google_compute_forwarding_rule" "demo2" {
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[count.index].project_id
  region = local.region_demo2

  name = "sql"
  ip_address = google_compute_address.demo2[count.index].address
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol = "TCP"
  port_range = "1433-1433"
  target = google_compute_region_target_tcp_proxy.demo2[count.index].id
  network = data.google_compute_network.demo2[count.index].id

  depends_on = [
    google_compute_subnetwork.demo2
  ]
}

resource "google_compute_region_disk" "demo2_data" {
  provider = google-beta
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[0].project_id
  region = local.region_demo2
  replica_zones = [
    local.zone_demo2,
    local.zone_secondary_demo2
  ]
  name = "data"
  type = "hyperdisk-balanced-high-availability"
  access_mode = "READ_WRITE_MANY"
  size = 100
  provisioned_iops = 3000
  provisioned_throughput = 140
}

resource "google_compute_region_disk" "demo2_quorum" {
  provider = google-beta
  count = local.enable_demo2 ? 1 : 0
  project = module.demo2[0].project_id
  region = local.region_demo2
  replica_zones = [
    local.zone_demo2,
    local.zone_secondary_demo2
  ]
  name = "quorum"
  type = "hyperdisk-balanced-high-availability"
  size = 4
  access_mode = "READ_WRITE_MANY"
  provisioned_iops = 2000
  provisioned_throughput = 140
}

resource "google_compute_attached_disk" "demo2_data" {
  for_each = {
    for entry in flatten([
      for module in module.demo2: [
        for instance in nonsensitive(module.instances): instance
      ]
    ]): "${entry.name}" => entry
  }

  project = module.demo2[0].project_id
  disk = google_compute_region_disk.demo2_data[0].id
  instance = each.value.id
  device_name = google_compute_region_disk.demo2_data[0].name
}

resource "google_compute_attached_disk" "demo2_quorum" {
  for_each = {
    for entry in flatten([
      for module in module.demo2: [
        for instance in nonsensitive(module.instances): instance
      ]
    ]): "${entry.name}" => entry
  }

  project = module.demo2[0].project_id
  disk = google_compute_region_disk.demo2_quorum[0].id
  instance = each.value.id
  device_name = google_compute_region_disk.demo2_quorum[0].name
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
