locals {
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  machineType = var.machineType
  nameDomain = var.nameDomain
  password = var.password
}

data "google_project" "project" {}

data "google_compute_network" "network" {
  name = local.network
}

data "google_compute_subnetwork" "subnetwork" {
  region = local.region
  name = local.subnetwork
}

module "apis" {
  source = "../apis"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
}

module "gce_default_scopes" {
  source = "../gce-default-scopes"
}

module "sysprep" {
  source = "../sysprep"
}

module "firewall_ca" {
  source = "../firewall-ca"
  namePrefix = "allow-ca"
  network = data.google_compute_network.network.self_link
  cidrRanges = [
    data.google_compute_subnetwork.subnetwork.ip_cidr_range
  ]
}

resource "google_compute_address" "ca_root" {
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  name = "ca-root"
  address_type = "INTERNAL"
  address = cidrhost(data.google_compute_subnetwork.subnetwork.ip_cidr_range, 3)
}

resource "google_compute_address" "ca_web" {
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  name = "ca-web"
  address_type = "INTERNAL"
  address = cidrhost(data.google_compute_subnetwork.subnetwork.ip_cidr_range, 4)
}

resource "google_compute_instance" "ca_root" {
  zone = local.zone
  name = "ca-root"
  machine_type = local.machineType

  tags = ["ca-root", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
    network_ip = google_compute_address.ca_root.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
        nameHost = "ca-root", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/ca-root.ps1"),
          nameDomain = local.nameDomain,
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
    scopes = module.gce_default_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
