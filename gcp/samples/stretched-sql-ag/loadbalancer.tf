
resource "google_compute_instance_group" "cluster_onprem" {
  project = module.project_onprem.id
  zone = local.zone_onprem
  name = "cluster"
  instances = [
    for instance in google_compute_instance.node_onprem:
    instance.self_link
  ]
  network = google_compute_network.onprem.self_link
}

resource "google_compute_instance_group" "cluster_cloud" {
  project = module.project_cloud.id
  zone = local.zone_cloud
  name = "cluster"
  instances = [
    for instance in google_compute_instance.node_cloud:
    instance.self_link
  ]
  network = google_compute_network.cloud.self_link
}

resource "google_compute_health_check" "cluster_cl_onprem" {
  project = module.project_onprem.id
  name = "cluster-cl"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  log_config {
    enable = true
  }

  tcp_health_check {
    port = 59998
    request = google_compute_address.cluster_cl_onprem.address
    response = "1"
  }
}

resource "google_compute_health_check" "cluster_cl_cloud" {
  project = module.project_cloud.id
  name = "cluster-cl"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  log_config {
    enable = true
  }

  tcp_health_check {
    port = 59998
    request = google_compute_address.cluster_cl_cloud.address
    response = "1"
  }
}

resource "google_compute_health_check" "cluster_sql_onprem" {
  project = module.project_onprem.id
  name = "cluster-sql"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  log_config {
    enable = true
  }

  tcp_health_check {
    port = 59998
    request = google_compute_address.cluster_sql_onprem.address
    response = "1"
  }
}

resource "google_compute_health_check" "cluster_sql_cloud" {
  project = module.project_cloud.id
  name = "cluster-sql"
  timeout_sec = 1
  check_interval_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 1

  log_config {
    enable = true
  }

  tcp_health_check {
    port = 59998
    request = google_compute_address.cluster_sql_cloud.address
    response = "1"
  }
}

resource "google_compute_region_backend_service" "cluster_cl_onprem" {
  project = module.project_onprem.id
  region = local.region_onprem
  name = "cluster-cl"
  health_checks = [
    google_compute_health_check.cluster_cl_onprem.id
  ]

  backend {
    group = google_compute_instance_group.cluster_onprem.id
  }
}

resource "google_compute_region_backend_service" "cluster_cl_cloud" {
  project = module.project_cloud.id
  region = local.region_cloud
  name = "cluster-cl"
  health_checks = [
    google_compute_health_check.cluster_cl_cloud.id
  ]

  backend {
    group = google_compute_instance_group.cluster_cloud.id
  }
}

resource "google_compute_region_backend_service" "cluster_sql_onprem" {
  project = module.project_onprem.id
  region = local.region_onprem
  name = "cluster-sql"
  health_checks = [
    google_compute_health_check.cluster_sql_onprem.id
  ]

  backend {
    group = google_compute_instance_group.cluster_onprem.id
  }
}

resource "google_compute_region_backend_service" "cluster_sql_cloud" {
  project = module.project_cloud.id
  region = local.region_cloud
  name = "cluster-sql"
  health_checks = [
    google_compute_health_check.cluster_sql_cloud.id
  ]

  backend {
    group = google_compute_instance_group.cluster_cloud.id
  }
}

resource "google_compute_forwarding_rule" "cluster_cl_onprem" {
  project = module.project_onprem.id
  region = local.region_onprem
  name = "cluster-cl"
  ip_address = google_compute_address.cluster_cl_onprem.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = google_compute_network.onprem.id
  subnetwork = google_compute_subnetwork.onprem.id
  backend_service = google_compute_region_backend_service.cluster_cl_onprem.id
}

resource "google_compute_forwarding_rule" "cluster_cl_cloud" {
  project = module.project_cloud.id
  region = local.region_cloud
  name = "cluster-cl"
  ip_address = google_compute_address.cluster_cl_cloud.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = google_compute_network.cloud.id
  subnetwork = google_compute_subnetwork.cloud.id
  backend_service = google_compute_region_backend_service.cluster_cl_cloud.id
}

resource "google_compute_forwarding_rule" "cluster_sql_onprem" {
  project = module.project_onprem.id
  region = local.region_onprem
  name = "cluster-sql"
  ip_address = google_compute_address.cluster_sql_onprem.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = google_compute_network.onprem.id
  subnetwork = google_compute_subnetwork.onprem.id
  backend_service = google_compute_region_backend_service.cluster_sql_onprem.id
}

resource "google_compute_forwarding_rule" "cluster_sql_cloud" {
  project = module.project_cloud.id
  region = local.region_cloud
  name = "cluster-sql"
  ip_address = google_compute_address.cluster_sql_cloud.address
  load_balancing_scheme = "INTERNAL"
  all_ports = true
  allow_global_access = true
  network = google_compute_network.cloud.id
  subnetwork = google_compute_subnetwork.cloud.id
  backend_service = google_compute_region_backend_service.cluster_sql_cloud.id
}
