provider "google" {
}

locals {
  region = var.region
  prefix = var.prefix
  zone = var.zone

  sample_name = "gke-sql-licensing"

  network_range = "10.11.0.0/16"
  network_range_gke_master = "192.168.0.0/28"
  network_range_gke_pods = "192.168.8.0/21"
  network_range_gke_services = "192.168.16.0/21"

  subnet_gke_pods = "subnet-gke-pods"
  subnet_gke_services = "subnet-gke-services"

  machine_type = var.machine_type
}

resource "random_pet" "cluster" {
  length = 1
}

resource "random_integer" "cluster" {
  min = 1000
  max = 9999
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
  ]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  project = module.project.id
  region = local.region
  name = local.region
  ip_cidr_range = local.network_range
  network = google_compute_network.network.id
  private_ip_google_access = true

  secondary_ip_range = [
    {
      range_name = local.subnet_gke_pods
      ip_cidr_range = local.network_range_gke_pods
    },
    {
      range_name = local.subnet_gke_services
      ip_cidr_range = local.network_range_gke_services
    }
  ]
}

module "nat" {
  source = "../../modules/nat"
  project = module.project.id

  region = local.region
  network = google_compute_network.network.name
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
}

resource "google_compute_disk" "licensed_disk_01" {
  project = module.project.id
  name  = "licensed-disk-01"
  type = "pd-standard"
  zone = local.zone
  licenses = [
    "projects/windows-sql-cloud/global/licenses/sql-server-2019-standard"
  ]
}

resource "google_compute_disk" "licensed_disk_02" {
  project = module.project.id
  name  = "licensed-disk-02"
  type = "pd-standard"
  zone = local.zone
  licenses = [
    "projects/windows-sql-cloud/global/licenses/sql-server-2019-standard"
  ]
}

resource "google_compute_instance" "test_01" {
  project = module.project.id
  zone = local.zone
  name = "test-01"
  machine_type = local.machine_type

  tags = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  attached_disk {
    source = google_compute_disk.licensed_disk_01.name
  }

  attached_disk {
    source = google_compute_disk.licensed_disk_02.name
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetwork.id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_container_cluster" "cluster" {
  project = module.project.id
  location = local.zone
  name = "${random_pet.cluster.id}-${random_integer.cluster.id}"

  network = google_compute_network.network.self_link
  subnetwork = google_compute_subnetwork.subnetwork.self_link
  networking_mode = "VPC_NATIVE"

  initial_node_count = 3

  # Private cluster (nodes without public IPs) but global Master
  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes   = true 
    master_ipv4_cidr_block = local.network_range_gke_master

    master_global_access_config {
      enabled = true
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = local.subnet_gke_pods
    services_secondary_range_name = local.subnet_gke_services
  }
  
  node_config {
    preemptible = true
    machine_type = local.machine_type

    service_account = "default"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    shielded_instance_config {
      enable_secure_boot = true
    }
  }

  deletion_protection = false
}