provider "google" {
  version = "~> 3.1"
  project = var.project
  region = var.region
  zone = var.zone
}

provider "google-beta" {
  version = "~> 3.1"
  project = var.project
  region = var.region
  zone = var.zone
}

locals {
  project = var.project
  region = var.region
  zone = var.zone
  name-sample = "openttd"
  network-range = "10.0.2.0/24"
  serverPassword = var.serverPassword
  adminPassword = var.adminPassword
  rconPassword = var.rconPassword
  generationSeed = var.generationSeed
  mapX = var.mapX
  mapY = var.mapY
}

module "apis" {
  source = "github.com/peterschen/blog//gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "cloudbuild.googleapis.com", "containerregistry.googleapis.com", "compute.googleapis.com"]
}

module "gce-default-scopes" {
  source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
}

resource "google_container_registry" "registry" {
  depends_on = [module.apis]
}

resource "google_cloudbuild_trigger" "master" {
  provider = google-beta

  github {
    owner = "peterschen"
    name = "blog"

    push {
      branch = "^master$"
    }
  }

  # filename = "/gcp/samples/openttd/cloudbuild.yaml"

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "-t", "gcr.io/${local.project}/openttd:$SHORT_SHA", "."]
    }

    images = ["gcr.io/${local.project}/openttd:$SHORT_SHA", "gcr.io/${local.project}/openttd:latest"]
  }

  depends_on = [google_container_registry.registry]
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
  depends_on = [module.apis]
}

resource "google_compute_subnetwork" "subnetwork" {
  name = local.region
  ip_cidr_range = local.network-range
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-openttd" {
  name    = "allow-openttd"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "udp"
    ports    = [3979]
  }

  allow {
    protocol = "tcp"
    ports    = [3979, 3977]
  }

  direction = "INGRESS"

  target_tags = ["openttd"]
}

resource "google_compute_address" "ip" {
  name = "openttd"
}

resource "google_compute_instance" "openttd" {
  name = "openttd"
  machine_type = "n1-standard-2"

  tags = ["openttd"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = google_compute_network.network.name
    subnetwork = google_compute_subnetwork.subnetwork.name
    access_config {
      nat_ip = google_compute_address.ip.address
    }
  }

  metadata = {
    sample = local.name-sample
    gce-container-declaration = templatefile("gce-container-declaration.yaml", {
      project = local.project,
      serverPassword = local.serverPassword,
      adminPassword = local.adminPassword,
      rconPassword = local.rconPassword,
      generationSeed = local.generationSeed,
      mapX = local.mapX,
      mapY = local.mapY
    })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  allow_stopping_for_update = true
}
