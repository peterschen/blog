provider "google" {
  version = "~> 3.4"
}

locals {
  project = var.project
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  uri-meta = var.uri-meta
  uri-configuration = var.uri-configuration
  password = var.password
}

module "sysprep" {
  source = "github.com/peterschen/blog/gcp/modules/sysprep"
}

module "apis" {
  source = "github.com/peterschen/blog/gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_firewall" "bastion-3389" {
  project = local.project
  name = "bastion-win-3389"
  network = local.network
  priority = 2500

  allow {
    protocol = "tcp"
    ports = ["3389"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["bastion-win"]
}

resource "google_compute_instance" "bastion" {
  project = local.project
  zone = local.zone
  name = "bastion-win"
  machine_type = "n1-standard-2"

  tags = ["bastion-win"]

  boot_disk {
    initialize_params {
      type = "pd-ssd"
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = local.network
    subnetwork = local.subnetwork
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
      nameHost = "bastion-win", 
      nameConfiguration = "bastion",
      uriMeta = local.uri-meta,
      uriConfigurations = local.uri-configuration,
      password = local.password,
      parametersConfiguration = jsonencode({})
    })
  }

  depends_on = ["module.apis"]
}
