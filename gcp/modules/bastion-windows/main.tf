locals {
  project = var.project
  zone = var.zone
  network = var.network
  subnetwork = var.subnetwork
  password = var.password
  machine-type = var.machine-type
  machine-name = var.machine-name
  name-domain = var.domain-name
  enable-domain = var.enable-domain
  enable-ssms = var.enable-ssms
  enable-hammerdb = var.enable-hammerdb
}

module "gce-default-scopes" {
  source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
}

module "sysprep" {
  source = "github.com/peterschen/blog//gcp/modules/sysprep"
}

module "apis" {
  source = "github.com/peterschen/blog//gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_instance" "bastion" {
  project = local.project
  zone = local.zone
  name = local.machine-name
  machine_type = local.machine-type

  tags = ["bastion-windows", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019-for-containers"
      type = "pd-balanced"
    }
  }

  network_interface {
    network = local.network
    subnetwork = local.subnetwork
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
      nameHost = local.machine-name, 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path-meta),
        inlineConfiguration = filebase64("${path.module}/bastion.ps1"),
        nameDomain = local.name-domain,
        enableDomain = local.enable-domain,
        enableSsms = local.enable-ssms,
        enableHammerdb = local.enable-hammerdb
      })
    })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  depends_on = [module.apis]
}
