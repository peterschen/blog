locals {
  sample_name = "pass"

  secretmanager_project = "cbpetersen-shared"

  prefix = var.prefix
  region = var.region
  zone = var.zone

  network_range = "10.11.0.0/16"
  network_range_gke_master = "192.168.0.0/28"
  network_range_gke_pods = "192.168.8.0/21"
  network_range_gke_services = "192.168.16.0/21"
  network_range_psa = "172.16.0.0/24"

  subnet_gke_pods = "subnet-gke-pods"
  subnet_gke_services = "subnet-gke-services"

  machine_type = var.machine_type

  repository_uri =  "https://gitlab.com/google-cloud-ce/googlers/cbpetersen/pass23.git"

  password = var.password
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
}

resource "random_pet" "cluster" {
  length = 1
}

resource "random_integer" "cluster" {
  min = 1000
  max = 9999
}

resource "random_pet" "database" {
  length = 1
}

resource "random_integer" "database" {
  min = 1000
  max = 9999
}

module "project" {
  source = "github.com/peterschen/blog//gcp/modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com"
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

resource "google_compute_global_address" "private_service_access" {
  project = module.project.id
  name = "private-service-access"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  address = split("/", local.network_range_psa)[0]
  prefix_length = split("/", local.network_range_psa)[1]
  network = google_compute_network.network.id
}

resource "google_service_networking_connection" "private_service_access" {
  network = google_compute_network.network.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_global_address.private_service_access.name
  ]
}

module "nat" {
  source = "github.com/peterschen/blog//gcp/modules/nat"
  project = module.project.id

  region = local.region
  network = google_compute_network.network.name
}

module "firewall_iap" {
  source = "github.com/peterschen/blog//gcp/modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
}

module "bastion" {
  source = "github.com/peterschen/blog//gcp/modules/bastion_windows"
  project = module.project.id

  region = local.region
  zone = local.zone

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  machine_type = "n2-standard-4"
  machine_name = "bastion"
  windows_image = "windows-cloud/windows-2022"
  password = "Admin123Admin123"

  enable_domain = false
  enable_ssms = true
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

    service_account = data.google_compute_default_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    shielded_instance_config {
      enable_secure_boot = true
    }
  }

  deletion_protection = false
}

# resource "google_container_node_pool" "pool" {
#   project = module.project.id
#   name = "non-spot"
#   cluster = google_container_cluster.cluster.id
#   node_count = 1

#   node_config {
#     machine_type = local.machine_type

#     service_account = data.google_compute_default_service_account.default.email
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform"
#     ]

#     shielded_instance_config {
#       enable_secure_boot = true
#     }
#   }
# }

resource "google_secret_manager_secret_iam_binding" "pat_api" {
  project = local.secretmanager_project
  secret_id = "pass-pat-api"
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:service-${module.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  ]
}

resource "google_secret_manager_secret_iam_binding" "pat_read_api" {
  project = local.secretmanager_project
  secret_id = "pass-pat-read-api"
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:service-${module.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  ]
}

data "google_secret_manager_secret_version_access" "pat_api" {
  project = local.secretmanager_project
  secret = "pass-pat-api"
}

data "google_secret_manager_secret_version_access" "pat_read_api" {
  project = local.secretmanager_project
  secret = "pass-pat-read-api"
}

resource "google_cloudbuildv2_connection" "connection" {
  project = module.project.id
  location = local.region
  name = "google-cloud-ce"

  gitlab_config {
    authorizer_credential {
      user_token_secret_version = data.google_secret_manager_secret_version_access.pat_api.id
    }

    read_authorizer_credential {
      user_token_secret_version = data.google_secret_manager_secret_version_access.pat_read_api.id
    }

    webhook_secret_secret_version = data.google_secret_manager_secret_version_access.pat_api.id
  }

  depends_on = [
    google_secret_manager_secret_iam_binding.pat_api,
    google_secret_manager_secret_iam_binding.pat_read_api
  ]
}

resource "google_cloudbuildv2_repository" "repository" {
  project = module.project.id
  location = local.region
  name = "pass"

  parent_connection = google_cloudbuildv2_connection.connection.name
  remote_uri = local.repository_uri
}

resource "google_artifact_registry_repository" "repository" {
  project = module.project.id
  location = local.region
  repository_id = "pass"
  format = "DOCKER"
}

resource "google_artifact_registry_repository_iam_binding" "compute" {
  project = module.project.id
  location = local.region
  repository = google_artifact_registry_repository.repository.name
  role = "roles/artifactregistry.reader"
  members = [
    "serviceAccount:${data.google_compute_default_service_account.default.email}"
  ]
}

resource "google_cloudbuild_trigger" "pr" {
  project = module.project.id
  location = local.region

  name = "pass-pr"

  repository_event_config {
    repository = google_cloudbuildv2_repository.repository.id

    push {
      branch = "pr-.*"
    }
  }

  filename = "build/pr.yml"

  substitutions = {
    _AF_REGION = local.region
    _AF_REPOSITORY = google_artifact_registry_repository.repository.name
    _GKE_LOCATION = local.zone
    _GKE_CLUSTER = "${random_pet.cluster.id}-${random_integer.cluster.id}"
  }
}

resource "google_project_iam_binding" "cloudbuild_clusteradmin" {
  project = module.project.id
  role = "roles/container.admin"
  members = [
    "serviceAccount:${module.project.number}@cloudbuild.gserviceaccount.com"
  ]
}

resource "google_storage_bucket" "bucket" {
  project = module.project.id
  name = module.project.id
  location = local.region
  force_destroy = true

  uniform_bucket_level_access = true
}
