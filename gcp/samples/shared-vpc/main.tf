terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
    google-beta = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
  project = var.hostProjectName
}

provider "google-beta" {
  project = var.hostProjectName
}

locals {
  region = var.region
  zone = var.zone
  nameSample = "shared-vpc"
  nameProjectHost = var.hostProjectName
  nameProjectService = var.serviceProjectName
  nameDomain = ""
  networkRange = "10.0.0.0/16"
  networkRangeActiveDirectory = "192.168.0.0/24"
  networkRangePrivateServiceAcccess = "192.168.1.0/24"
  password = var.password
  enableDomain = false
}

module "apisHost" {
  source = "../../modules/apis"
  project = data.google_project.host.project_id
  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com"
  ]
}

module "apisService" {
  source = "../../modules/apis"
  project = data.google_project.service.project_id
  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ]
}

data "google_project" "host" {
  project_id = local.nameProjectHost
}

data "google_project" "service" {
  project_id = local.nameProjectService
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = data.google_project.host.project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  host_project = google_compute_shared_vpc_host_project.host.project
  service_project = data.google_project.service.project_id
}

resource "google_compute_network" "network" {
  project = data.google_project.host.project_id
  name = local.nameSample
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = data.google_project.host.project_id
  region = local.region
  name = local.region
  ip_cidr_range = local.networkRange
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_global_address" "privateServiceAccess" {
  project = data.google_project.host.project_id
  name = "${local.nameSample}-psa"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  address = split("/", local.networkRangePrivateServiceAcccess)[0]
  prefix_length = split("/", local.networkRangePrivateServiceAcccess)[1]
  network = google_compute_network.network.id
}

resource "google_service_networking_connection" "privateServiceAccess" {
  network = google_compute_network.network.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.privateServiceAccess.name
  ]
  
  depends_on = [
    module.apisService
  ]
}

resource "google_active_directory_domain" "ad-domain" {
  domain_name = "${replace(local.nameSample, "-", "")}.lab"

  locations = [
    local.region
  ]

  reserved_ip_range = local.networkRangeActiveDirectory

  authorized_networks = [
    "projects/${google_compute_network.network.project}/global/networks/${google_compute_network.network.name}"
  ]
}

resource "google_project_service_identity" "sqladmin" {
  provider = google-beta
  project = data.google_project.service.project_id
  service = "sqladmin.googleapis.com"
}

resource "google_project_iam_binding" "sqladmin_sqlintegrator" {
  role = "roles/managedidentities.sqlintegrator"
  members = [
    "serviceAccount:${google_project_service_identity.sqladmin.email}",
  ]
}

module "cloudNat" {
  source = "../../modules/cloud-nat"
  region = local.region
  network = google_compute_network.network.name
  depends_on = [
    google_compute_network.network
  ]
}

module "firewall-iap" {
  source = "../../modules/firewall-iap"
  network = google_compute_network.network.name
  enable-ssh = false
}

module "bastion" {
  source = "../../modules/bastion_windows"
  project = data.google_project.service.project_id
  projectNetwork = data.google_project.host.project_id
  region = local.region
  zone = local.zone
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name
  machine-type = "n2-standard-4"
  machine-name = "bastion"
  password = local.password
  enable-domain = false
  enable-ssms = true
  depends_on = [module.cloudNat]
}

resource "google_compute_firewall" "allow-all-mad" {
  name    = "allow-all-mad"
  network = google_compute_network.network.name
  priority = 5000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.networkRangeActiveDirectory
  ]
}

resource "google_compute_firewall" "allow-all-psa" {
  name    = "allow-all-psa"
  network = google_compute_network.network.name
  priority = 5000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    local.networkRangePrivateServiceAcccess
  ]
}
