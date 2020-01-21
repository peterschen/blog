provider "google" {
  version = "~> 3.4"
  project = var.project
  zone = var.zone
}

locals {
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_project_service" "apis" {
  count = length(local.apis)
  service = local.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_compute_instance" "bastion" {
  name = "bastion"
  machine_type = "n1-standard-2"

  tags = ["bastion", "rdp"]

  boot_disk {
    initialize_params {
      type = "pd-ssd"
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = var.network
    subnetwork = var.subnet
  }

  metadata = {
    sample = local.name-sample
    type = "jumpy"
    sysprep-specialize-script-ps1 = "$passwordSecure = ConvertTo-SecureString -String ${var.password} -AsPlainText -Force; Set-LocalUser -Name Administrator -Password $passwordSecure; Enable-LocalUser -Name Administrator;"
  }

  depends_on = ["google_project_service.apis"]
}