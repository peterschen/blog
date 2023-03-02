resource "google_sql_database_instance" "cepf-db" {
  name = "cepf-db"
  database_version = "POSTGRES_14"
  region = "us-central1"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_compute_instance_template" "cepf-app" {
  name_prefix = "cepf-app-"
  region = local.regions[0]
  machine_type = local.machine_type_joinvm

  tags = ["ssh"]

  disk {
    source_image = 
    auto_delete = true
    boot = true
    disk_type = "pd-balanced"
    disk_size_gb = 50
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetworks[0].id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "joinvm" {
  name = "cepf-app"
  zone = 
  base_instance_name = 
  
  version {
    instance_template = google_compute_instance_template.joinvm[count.index].id
  }

  target_size = 1
}

resource "google_compute_region_backend_service" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  
  load_balancing_scheme = "INTERNAL_MANAGED"

  protocol = "HTTP"
  port_name = "adjoin"
  timeout_sec = 30
  health_checks = [google_compute_region_health_check.adjoin[count.index].id]

  backend {
    group = google_compute_region_instance_group_manager.adjoin[count.index].instance_group
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  default_service = google_compute_region_backend_service.adjoin[count.index].id
}

resource "google_compute_region_target_http_proxy" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  url_map = google_compute_region_url_map.adjoin[count.index].id
}

resource "google_compute_forwarding_rule" "cepf-app-lb" {
  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  
  
  port_range = "8080"
  target = google_compute_region_target_http_proxy.adjoin[count.index].id
  network = google_compute_network.network.id
  subnetwork = google_compute_subnetwork.subnetworks[count.index].id

  # Explicit dependency required so things can be desotryed properly
  depends_on = [
    google_compute_subnetwork.proxy_lb
  ]
}