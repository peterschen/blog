locals {
  region = var.region
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  machine_type = var.machine_type
  domain_name = var.domain_name
  password = var.password

  # If Cloud Identity domain is not provided use the domain name
  cloud_identity_domain = var.cloud_identity_domain != null ? var.cloud_identity_domain : local.domain_name
  
  windows_image = var.windows_image
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

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

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
  machine_type = local.machine_type

  tags = ["fs", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
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
          nameDomain = local.domain_name,
          cloudIdentityDomain = local.cloud_identity_domain,
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
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
