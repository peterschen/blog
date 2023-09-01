provider "google" {
}

locals {
  prefix = var.prefix
  region = var.region
  zone = var.zone
  
  sample_name = "syslog-2-cloudlogging"

  network_mask = 16
  network_range = "10.0.0.0/${local.network_mask}"
  network_range_ad= "192.168.0.0/24"
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ]
}

resource "google_project_iam_binding" "logwriter" {
  project = module.project.id

  role = "roles/logging.logWriter"

  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}"
  ]
}

resource "google_project_iam_binding" "metricwriter" {
  project = module.project.id

  role = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}"
  ]
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

module "nat" {
  source = "../../modules/nat"
  project = module.project.id

  region = local.region
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
  enable_rdp = false
  enable_ssh = true
}

resource "google_compute_firewall" "allow_all_internal" {
  name    = "allow-all-internal"
  project = module.project.id

  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range
  ]
}

resource "google_compute_firewall" "allow_rsyslog_internal" {
  project = module.project.id
  name = "allow-rsyslog-internal"
  network = google_compute_network.network.id
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["514"]
  }

  allow {
    protocol = "udp"
    ports    = ["514"]
  }

  direction = "INGRESS"

  source_ranges = [
    local.network_range
  ]
  target_tags = ["syslog"]
}

resource "google_compute_address" "syslog" {
  project = module.project.id
  region = local.region
  subnetwork = google_compute_subnetwork.subnetwork.id
  name = "syslog"
  address_type = "INTERNAL"
  address = cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 100)
}

resource "google_compute_instance" "syslog" {
  project = module.project.id
  zone = local.zone
  name = "syslog"
  machine_type = "e2-medium"

  tags = ["ssh", "syslog"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-balanced"
    }
  }

  can_ip_forward = true
  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetwork.id
    network_ip = google_compute_address.syslog.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    startup-script=<<-EOM
      #!/usr/bin/env bash

      set +eux

      curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
      bash add-google-cloud-ops-agent-repo.sh --also-install

      cat <<- EOF > /etc/google-cloud-ops-agent/config.yaml
        logging:
          receivers:
            syslog-tcp:
              type: syslog
              
              transport_protocol: tcp
              listen_host: 0.0.0.0
              listen_port: 5140

          service:
            pipelines:
              default_pipeline:
                receivers: [syslog, syslog-tcp]
      EOF

      service google-cloud-ops-agent restart
    EOM
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true  
}

resource "google_compute_instance_template" "generator" {
  project = module.project.id

  name_prefix = "generator-"
  region = local.region
  machine_type = "e2-medium"

  tags = ["ssh"]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete = true
    boot = true
    disk_type = "pd-balanced"
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

    metadata = {
    startup-script=<<-EOM
      #!/usr/bin/env bash

      set +eux

      apt-get install rsyslog -y

      cat <<- EOF > /etc/rsyslog.d/10-remoting.conf
        # *.* @@${google_compute_address.syslog.address}:514
        action(type="omfwd" Target="${google_compute_address.syslog.address}" Port="5140" Protocol="tcp")
      EOF

      systemctl restart rsyslog

      while true; do
        logger "Log test"
        sleep 1
      done
    EOM
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "generator" {
  project = module.project.id

  name = "generator"
  zone = local.zone
  base_instance_name = "generator"
  
  version {
    instance_template = google_compute_instance_template.generator.id
  }

  target_size = 0
}
