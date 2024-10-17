module "demo5" {
  count = local.enable_demo5 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo5
  prefix = "passdemo5"

  region = local.region_demo5
  zones = [
    local.zone_demo5
  ]

  domain_name = local.domain_name
  password = var.password
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "n2-highcpu-4"
}

resource "google_compute_subnetwork" "secondary_subnetwork" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  region = local.region_secondary_demo5
  name = local.region_secondary_demo5
  ip_cidr_range = "10.1.0.0/16"
  network = module.demo5[count.index].network_id
  private_ip_google_access = true
}

module "nat" {
  count = local.enable_demo5 ? 1 : 0
  source = "../../modules/nat"
  project = module.demo5[count.index].project_id

  region = local.region_secondary_demo5
  network = module.demo5[count.index].network_name

  depends_on = [
    module.demo5[0]
  ]
}

resource "google_compute_firewall" "allow-all-internal" {
  count = local.enable_demo5 ? 1 :0
  name = "allow-all-internal-demo5"
  project = module.demo5[count.index].project_id

  network = module.demo5[count.index].network_name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    google_compute_subnetwork.secondary_subnetwork[0].ip_cidr_range
  ]
}

module "sqlserver_demo5" {
  count = local.enable_demo5 ? 1 : 0
  source = "../../modules/sqlserver"
  project = module.demo5[count.index].project_id
  region = local.region_secondary_demo5
  zones = [
    local.zone_secondary_demo5
  ]

  network = module.demo5[count.index].network_name
  subnetwork = google_compute_subnetwork.secondary_subnetwork[count.index].name
  
  domain_name = local.domain_name
  password = var.password
  
  machine_prefix = "sql-clone"
  machine_type = "n2-highcpu-4"

  # Firewall configuration already made by other sqlserver deployment
  enable_firewall = false
  enable_cluster = false
  enable_alwayson = false

  depends_on = [
    google_compute_subnetwork.secondary_subnetwork
  ]
}

resource "google_compute_resource_policy" "demo5_group" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  name = "sql"
  region = local.region_demo5

  disk_consistency_group_policy {
    enabled = true
  }
}

resource "google_compute_resource_policy" "demo5_secondary_group" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  name = "sql"
  region = local.region_secondary_demo5

  disk_consistency_group_policy {
    enabled = true
  }
}

resource "google_compute_disk" "demo5_data" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  zone = local.zone_demo5
  name = "data"
  type = "pd-balanced"
  size = 50
}

resource "google_compute_disk" "demo5_log" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  zone = local.zone_demo5
  name = "log"
  type = "pd-balanced"
  size = 50
}

resource "google_compute_disk" "demo5_secondary_data" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  zone = local.zone_secondary_demo5
  name = "data"
  type = "pd-balanced"
  size = 50

  async_primary_disk {
    disk = google_compute_disk.demo5_data[count.index].id
  }
}

resource "google_compute_disk" "demo5_secondary_log" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  zone = local.zone_secondary_demo5
  name = "log"
  type = "pd-balanced"
  size = 50

  async_primary_disk {
    disk = google_compute_disk.demo5_log[count.index].id
  }
}

resource "google_compute_disk_resource_policy_attachment" "demo5_data" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  name = google_compute_resource_policy.demo5_group[count.index].name
  disk = google_compute_disk.demo5_data[count.index].name
  zone = google_compute_disk.demo5_data[count.index].zone
}

resource "google_compute_disk_resource_policy_attachment" "demo5_log" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  name = google_compute_resource_policy.demo5_group[count.index].name
  disk = google_compute_disk.demo5_log[count.index].name
  zone = google_compute_disk.demo5_log[count.index].zone
}

resource "google_compute_disk_resource_policy_attachment" "demo5_secondary_data" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  name = google_compute_resource_policy.demo5_secondary_group[count.index].name
  disk = google_compute_disk.demo5_secondary_data[count.index].name
  zone = google_compute_disk.demo5_secondary_data[count.index].zone
}

resource "google_compute_disk_resource_policy_attachment" "demo5_secondary_log" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  name = google_compute_resource_policy.demo5_secondary_group[count.index].name
  disk = google_compute_disk.demo5_secondary_log[count.index].name
  zone = google_compute_disk.demo5_secondary_log[count.index].zone
}

resource "google_compute_disk_async_replication" "demo5_data" {
  count = local.enable_demo5 ? 1 : 0
  primary_disk = google_compute_disk.demo5_data[count.index].id
  secondary_disk {
    disk  = google_compute_disk.demo5_secondary_data[count.index].id
  }

  depends_on = [ 
    google_compute_disk_resource_policy_attachment.demo5_data[0]
  ]
}

resource "google_compute_disk_async_replication" "demo5_log" {
  count = local.enable_demo5 ? 1 : 0
  primary_disk = google_compute_disk.demo5_log[count.index].id
  secondary_disk {
    disk  = google_compute_disk.demo5_secondary_log[count.index].id
  }

  depends_on = [ 
    google_compute_disk_resource_policy_attachment.demo5_log[0]
  ]
}

resource "google_compute_attached_disk" "demo5_data" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  disk = google_compute_disk.demo5_data[count.index].id
  instance = module.demo5[count.index].instances[0].id
  device_name = google_compute_disk.demo5_data[count.index].name
}

resource "google_compute_attached_disk" "demo5_log" {
  count = local.enable_demo5 ? 1 : 0
  project = module.demo5[count.index].project_id
  disk = google_compute_disk.demo5_log[count.index].id
  instance = module.demo5[count.index].instances[0].id
  device_name = google_compute_disk.demo5_log[count.index].name
}
