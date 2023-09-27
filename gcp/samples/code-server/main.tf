terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
}

locals {
  prefix = var.prefix
  region = var.region
  zone = var.zone

  secretmanager_project = "cbpetersen-shared"

  sample_name = "code"
  
  network_range = "10.10.0.0/16"

  machine_type = "e2-medium"

  boot_disk_type = "pd-balanced"
  boot_disk_size = 20

  data_disk_type = "pd-balanced"
  data_disk_size = 100
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "compute.googleapis.com"
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
  enable_rdp = false
  enable_http_alt = true
}

resource "google_compute_address" "code" {
  project = module.project.id
  region = local.region
  subnetwork = google_compute_subnetwork.subnetwork.id
  name = "code"
  address_type = "INTERNAL"
  address = cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 10)
}

resource "google_compute_disk" "data" {
  project = module.project.id
  zone = local.zone
  name = "code-data"
  type = local.data_disk_type
  size = local.data_disk_size
}

resource "google_compute_resource_policy" "policy" {
  project = module.project.id
  name = "data-daily"
  region = local.region

  snapshot_schedule_policy {
    schedule {
      hourly_schedule {
        hours_in_cycle = 1
        start_time = "00:00"
      }
    }

    retention_policy {
      max_retention_days = 30
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "attachment" {
  project = module.project.id
  name = google_compute_resource_policy.policy.name
  disk = google_compute_disk.data.name
  zone = local.zone
}

resource "google_compute_instance" "code" {
  project = module.project.id
  zone = local.zone
  name = "code"
  machine_type = local.machine_type

  tags = ["ssh", "http-alt-iap"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      type = local.boot_disk_type
      size = local.boot_disk_size
    }
  }

  attached_disk {
    source = google_compute_disk.data.id
    device_name = "data"
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetwork.id
    network_ip = google_compute_address.code.address
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

      disk=/dev/disk/by-id/google-data

      # Install packages
      apt-get install -y git

      # Create folders
      mkdir -p /root/config/sa
      mkdir -p /root/.ssh
      
      # Download key material
      gcloud secrets versions access "latest" --project cbpetersen-shared --secret codeserver-sa --out-file /root/config/sa/codeserver@cbpetersen-shared.json
      gcloud secrets versions access "latest" --project cbpetersen-shared --secret codeserver-ssh-private-key --out-file /root/.ssh/id_rsa
      gcloud secrets versions access "latest" --project cbpetersen-shared --secret codeserver-ssh-public-key --out-file /root/.ssh/id_rsa.pub

      # Fix SSH certificate permissions
      chmod 600 /root/.ssh/id_rsa

      # Format data disk if it does not have a filesystem
      file_system=`lsblk -no FSTYPE $disk`
      if [ "$file_system" == "" ]; then
        mkfs.ext4 $disk
      fi

      # Mount data disk
      mkdir -p /data
      mount $disk /data
      
      # Create subdirectories on data disk
      mkdir -p /data/user-data
      mkdir -p /data/extension
      mkdir -p /data/dev

      # Set code-server configuration
      mkdir -p /root/.config/code-server
      cat <<- EOF > /root/.config/code-server/config.yaml
        bind-addr: 0.0.0.0:8080
        auth: none
        cert: false

        user-data-dir: /data/user-data
        extensions-dir: /data/extensions
      EOF

      # Install and enable code-server
      curl -fsSL https://code-server.dev/install.sh | sh
      systemctl enable --now code-server@$USER
    EOM
  }

  allow_stopping_for_update = true  
}

resource "google_secret_manager_secret_iam_binding" "sa" {
  project = local.secretmanager_project
  secret_id = "codeserver-sa"
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "ssh_private_key" {
  project = local.secretmanager_project
  secret_id = "codeserver-ssh-private-key"
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "ssh_public_key" {
  project = local.secretmanager_project
  secret_id = "codeserver-ssh-public-key"
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}",
  ]
}

resource "google_project_iam_binding" "code" {
  project = local.secretmanager_project
  role = "roles/source.reader"

  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}"
  ]
}