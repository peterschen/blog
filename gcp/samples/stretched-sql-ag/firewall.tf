module "firewall_iap_onprem" {
  source = "../../modules/firewall_iap"
  project = module.project_onprem.id
  network = google_compute_network.onprem.name
  enable_ssh = true
}

module "firewall_iap_cloud" {
  source = "../../modules/firewall_iap"
  project = module.project_cloud.id
  network = google_compute_network.cloud.name
  enable_ssh = true
}

resource "google_compute_firewall" "allow_all_internal_onprem" {
  name    = "allow-all-internal"
  project = module.project_onprem.id

  network = google_compute_network.onprem.name
  priority = 800

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range_onprem
  ]
}

resource "google_compute_firewall" "allow_all_internal_cloud" {
  name    = "allow-all-internal"
  project = module.project_cloud.id

  network = google_compute_network.cloud.name
  priority = 800

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range_cloud
  ]
}

resource "google_compute_firewall" "allow_all_cloud" {
  name = "allow-all-cloud"
  project = module.project_onprem.id
  network = google_compute_network.onprem.name
  priority = 900

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range_cloud
  ]
}

resource "google_compute_firewall" "allow_all_onprem" {
  name = "allow-all-onprem"
  project = module.project_cloud.id
  network = google_compute_network.cloud.name
  priority = 900

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range_onprem
  ]
}

resource "google_compute_firewall" "allow_dns_gcp" {
  project = module.project_cloud.id
  name = "allow-dns-gcp"
  network = google_compute_network.cloud.id
  priority = 4000

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  direction = "INGRESS"

  source_ranges = [
    "35.199.192.0/19"
  ]

  target_tags = ["dns"]
}

resource "google_compute_firewall" "allow_healthcheck_cluster_gcp_onprem" {
  name = "allow-healthcheck-cluster-gcp"
  project = module.project_onprem.id

  network = google_compute_network.onprem.id
  priority = 4000

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = [
    "cluster"
  ]
}

resource "google_compute_firewall" "allow_healthcheck_cluster_gcp_cloud" {
  name = "allow-healthcheck-cluster-gcp"
  project = module.project_cloud.id

  network = google_compute_network.cloud.id
  priority = 4000

  allow {
    protocol = "tcp"
    ports    = ["59998"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = [
    "cluster"
  ]
}
