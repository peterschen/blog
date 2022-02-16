locals {
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  machineType = var.machineType
  nameDomain = var.nameDomain
  password = var.password

  # If Cloud Identity domain is not provided use the domain name
  cloudIdentityDomain = var.cloudIdentityDomain != null ? var.cloudIdentityDomain : local.nameDomain
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

# module "firewall_adfs" {
#   source = "../firewall-adfs"
#   namePrefix = "allow-adfs"
#   network = data.google_compute_network.network.self_link
#   cidrRanges = [
#     data.google_compute_subnetwork.subnetwork.ip_cidr_range
#   ]
# }

resource "google_compute_address" "fs" {
  region = local.region
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link
  name = "fs"
  address_type = "INTERNAL"
  address = cidrhost(data.google_compute_subnetwork.subnetwork.ip_cidr_range, 4)
}

resource "google_compute_instance" "fs" {
  zone = local.zone
  name = "fs"
  machine_type = local.machineType

  tags = ["fs", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetwork.self_link
    network_ip = google_compute_address.fs.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
        nameHost = "fs", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/fs.ps1"),
          nameDomain = local.nameDomain,
          cloudIdentityDomain = local.cloudIdentityDomain,
          modulesDsc = [
            {
              Name = "CertificateDsc",
              Version = "5.1.0"
            },
            {
              Name = "AdfsDsc",
              Version = "1.1.0"
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
