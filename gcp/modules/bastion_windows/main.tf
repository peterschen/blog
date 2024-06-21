locals {
  project = var.project
  project_network = var.project_network == null ? var.project : var.project_network

  region = var.region
  zone = var.zone

  network = var.network
  subnetwork = var.subnetwork

  password = var.password

  machine_type = var.machine_type
  windows_image = var.windows_image

  machine_name = var.machine_name
  domain_name = var.domain_name

  enable_domain = var.enable_domain
  enable_ssms = var.enable_ssms
  enable_hammerdb = var.enable_hammerdb
  enable_diskspd = var.enable_diskspd
  enable_python = var.enable_python
  enable_discoveryclient = var.enable_discoveryclient
  enable_windowsadmincenter = var.enable_windowsadmincenter
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

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

module "apis" {
  source = "../apis"
  project = data.google_project.default.project_id
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}

resource "google_compute_address" "bastion" {
  region = local.region
  project = data.google_project.default.project_id
  
  name = local.machine_name
  subnetwork = data.google_compute_subnetwork.subnetwork.self_link

  address_type = "INTERNAL"
}

resource "google_compute_instance" "bastion" {
  project = data.google_project.default.project_id
  zone = local.zone
  name = local.machine_name
  machine_type = local.machine_type

  tags = ["bastion-windows", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = strcontains(local.machine_type, "n4") ? "hyperdisk-balanced" : "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.network.id
    subnetwork = data.google_compute_subnetwork.subnetwork.id
    network_ip = google_compute_address.bastion.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
      nameHost = local.machine_name, 
      password = local.password,
      parametersConfiguration = jsonencode({
        inlineMeta = filebase64(module.sysprep.path_meta),
        inlineConfiguration = filebase64("${path.module}/bastion.ps1"),
        nameDomain = local.domain_name,
        enableDomain = local.enable_domain,
        enableSsms = local.enable_ssms,
        enableHammerdb = local.enable_hammerdb,
        enableDiskspd = local.enable_diskspd,
        enablePython = local.enable_python,
        enableDiscoveryClient = local.enable_discoveryclient,
        enableWindowsAdminCenter = local.enable_windowsadmincenter,
        fileContentBenchmark = filebase64("${path.module}/benchmark.ps1"),
        fileContentBenchmarkConfigurations = filebase64("${path.module}/benchmark_configurations.json"),
        fileContentBenchmarkScenarios = filebase64("${path.module}/benchmark_scenarios.json")
      })
    })
  }

  service_account {
    scopes = module.gce_scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [
    module.apis
  ]
}
