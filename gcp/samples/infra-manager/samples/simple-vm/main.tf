provider "google" {
}

locals {
  prefix = var.prefix
  region = var.region
  zone = var.zone

  sample_name = "infra-manager-simple-vm"
  
  network_range = "10.10.0.0/16"

  machine_type = var.machine_type
}

module "project" {
  source = "../../../../modules/project"

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

module "firewall_iap" {
  source = "../../../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
  enable_rdp = false
  enable_http_alt = true
  enable_dotnet_http = true
  enable_dotnet_https = true
}

resource "google_compute_instance" "instance" {
  project = module.project.id
  zone = local.zone
  name = "simple-vm"
  machine_type = local.machine_type

  tags = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
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

  allow_stopping_for_update = true  
}
