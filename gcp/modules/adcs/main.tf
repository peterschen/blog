locals {
  project = var.project
  project_network = var.project_network != null ? var.project_network : var.project

  region = var.region
  zone = var.zone
  
  network = var.network
  subnetwork = var.subnetwork
  
  machine_type = var.machine_type
  windows_image = var.windows_image
  
  domain_name = var.domain_name
  password = var.password
}

data "google_project" "default" {
  project_id = local.project
}

data "google_project" "network" {
  project_id = local.project_network
}

data "google_compute_network" "network" {
  project = data.google_project.network.project_id
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  project = data.google_project.network.project_id
  region = local.region
  name = local.subnetwork
}

module "apis" {
  source = "../apis"
  project = data.google_project.default.project_id
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
}

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

module "firewall_ca" {
  source = "../firewall_ca"
  project = data.google_project.default.project_id

  name = "allow-ca"
  network = data.google_compute_network.network.self_link
  cidr_ranges = [
    data.google_compute_subnetwork.subnetwork.ip_cidr_range
  ]
}

resource "google_compute_address" "ca" {
  region = local.region
  project = data.google_project.default.project_id
  
  name = "ca"
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link

  address_type = "INTERNAL"
}

resource "google_compute_instance" "ca" {
  zone = local.zone
  project = data.google_project.default.project_id
  
  name = "ca"
  machine_type = local.machine_type

  tags = ["ca", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
    network_ip = google_compute_address.ca.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "ca", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/ca.ps1"),
          nameDomain = local.domain_name,
          modulesDsc = [
            {
              Name = "ActiveDirectoryCSDsc",
              Version = "5.0.0"
            }
          ]
        })
      })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
