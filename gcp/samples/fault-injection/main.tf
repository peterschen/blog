terraform {
  required_providers {
    google = {
      version = "~> 7.28"
    }

    google-beta = {
      version = "~> 7.28"
    }
  }
}

provider "google" {
  add_terraform_attribution_label = false
}

provider "google-beta" {
  add_terraform_attribution_label = false
}

locals {
  prefix = var.prefix
  region = var.region
  zone = var.zone

  sample_name = "fault-injection"
  
  network_range = "10.10.0.0/16"
  network_range_lb = "192.168.0.0/24"

  machine_type = var.machine_type
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "compute.googleapis.com",
    "faulttesting.googleapis.com"
  ]
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = module.project.id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "lb" {
  project = module.project.id
  region = local.region
  name = "lb"
  ip_cidr_range = local.network_range_lb
  network = google_compute_network.network.id
  purpose = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}

module "nat" {
  source = "../../modules/nat"
  project = module.project.id

  region = local.region
  network = google_compute_network.network.name
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
  enable_ssh = true
  enable_rdp = false
}

resource "google_compute_firewall" "allow_http_healthcheck" {
  name = "allow-http-healthcheck"
  project = module.project.id
  network = google_compute_network.network.name
  priority = 4000

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = ["http"]
}

resource "google_compute_firewall" "allow_http_lb" {
  name = "allow-http-lb"
  project = module.project.id
  network = google_compute_network.network.name
  priority = 4500

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  direction = "INGRESS"

  source_ranges = [local.network_range_lb]
  target_tags = ["http"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_http" {
  name = "allow-http"
  project = module.project.id
  network = google_compute_network.network.name
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  direction = "INGRESS"

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["http"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_project_iam_member" "log_writer" {
  project = module.project.id
  role = "roles/logging.logWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = module.project.id
  role = "roles/monitoring.metricWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_compute_instance" "individual_vm" {
  project = module.project.id
  zone = local.zone
  name = "individual-vm"
  machine_type = local.machine_type

  tags = ["ssh", "http"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13-arm64"
      type = "hyperdisk-balanced"
      size = 50
      provisioned_iops = 3000
      provisioned_throughput = 140
    }
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetwork.id

    # Enable ephemeral public IP
    access_config {
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script=<<-EOM
      #!/usr/bin/env bash
      set +eux

      apt install nginx -y

      header="Metadata-Flavor: Google"
      hostname=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "$${header}"`
      zone=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "$${header}"`

      cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<title>Cloud FIT demo</title>
<style>body{font-family:sans-serif;background:#f0f0f0;}</style>
<center>
<h1>Hostname: $hostname</h1>
<h1>Zone: $zone</h1>
</center>
EOF
    EOM
  }

  allow_stopping_for_update = true  
}

resource "google_compute_region_instance_template" "rmig" {
  project = module.project.id

  name_prefix = "rmig-"
  region = local.region
  machine_type = local.machine_type

  tags = ["ssh", "http"]

  disk {
    source_image = "debian-cloud/debian-13-arm64"
    auto_delete = true
    boot = true
    disk_type = "hyperdisk-balanced"
    disk_size_gb = 50
    provisioned_iops = 3000
    provisioned_throughput = 140
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetwork.id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script=<<-EOM
      #!/usr/bin/env bash
      set +eux

      apt install nginx -y

      header="Metadata-Flavor: Google"
      hostname=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "$${header}"`
      zone=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "$${header}"`

      cat << EOF > /var/www/html/index.html
<!DOCTYPE html>
<title>Cloud FIT demo</title>
<style>body{font-family:sans-serif;background:#f0f0f0;}</style>
<center>
<h1>Hostname: $hostname</h1>
<h1>Zone: $zone</h1>
</center>
EOF
    EOM
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_health_check" "http" {
  project = module.project.id
  region = local.region
  name = "http"
  check_interval_sec = 10
  timeout_sec = 1
  healthy_threshold = 1
  unhealthy_threshold = 3

  http_health_check {
    port_name = "http"
  }
}

resource "google_compute_region_instance_group_manager" "rmig" {
  project = module.project.id
  name = "rmig"
  region = local.region
  distribution_policy_zones = ["europe-west4-a", "europe-west4-c"]
  base_instance_name = "rmig"
  
  version {
    instance_template = google_compute_region_instance_template.rmig.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check = google_compute_region_health_check.http.id
    initial_delay_sec = 300
  }

  target_size = 2
}

resource "google_compute_region_backend_service" "http" {
  project = module.project.id
  region = local.region
  name = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol = "HTTP"
  port_name = "http"
  timeout_sec = 5
  health_checks = [google_compute_region_health_check.http.id]
  # session_affinity = "CLIENT_IP"
  locality_lb_policy = "ROUND_ROBIN"

  backend {
    group = google_compute_region_instance_group_manager.rmig.instance_group
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable = true
    sample_rate = 1
    optional_mode = "INCLUDE_ALL_OPTIONAL"
  }
}

resource "google_compute_region_url_map" "http" {
  project = module.project.id
  region = local.region
  name = "http"
  default_service = google_compute_region_backend_service.http.id
}

resource "google_compute_region_target_http_proxy" "http" {
  project = module.project.id
  region = local.region
  name = "http"
  url_map = google_compute_region_url_map.http.id
}

resource "google_compute_forwarding_rule" "http" {
  project = module.project.id
  region = local.region
  name = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol = "TCP"
  port_range = "80"
  target = google_compute_region_target_http_proxy.http.id
  network = google_compute_network.network.id

  depends_on = [google_compute_subnetwork.lb]
}