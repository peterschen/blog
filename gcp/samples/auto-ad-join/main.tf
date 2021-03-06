terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
  project = var.project
}

locals {
  regions = var.regions
  zones = var.zones
  region-scheduler = var.region-scheduler
  name-sample = "auto-ad-join"
  name-domain = var.domain-name
  password = var.password
  network-prefixes = ["10.0.0", "10.1.0"]
  network-mask = 16
  network-ranges = [
    for prefix in local.network-prefixes:
    "${prefix}.0/${local.network-mask}"
  ]
  network-range-serverless = "10.8.0.0/28"
  ip-dcs = [
    for prefix in local.network-prefixes:
    "${prefix}.2"
  ]

  image-families = [
    "gce-uefi-images/windows-1809-core-for-containers",
    "gce-uefi-images/windows-1809-core",
    "gce-uefi-images/windows-1903-core-for-containers",
    "gce-uefi-images/windows-1903-core",
    "gce-uefi-images/windows-1909-core-for-containers",
    "gce-uefi-images/windows-1909-core",
    "windows-cloud/windows-2004-core",
    "windows-cloud/windows-2012-r2-core",
    "windows-cloud/windows-2012-r2",
    "windows-cloud/windows-2016",
    "windows-cloud/windows-2016-core",
    "windows-cloud/windows-2019-core-for-containers",
    "windows-cloud/windows-2019-core",
    "windows-cloud/windows-2019-for-containers",
    "windows-cloud/windows-2019",
    "windows-cloud/windows-20h2-core"
  ]
}

data "google_project" "project" {}

data "google_compute_default_service_account" "default" {}

module "apis" {
  source = "../../modules/apis"
  apis = [
    "appengine.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "vpcaccess.googleapis.com"
  ]
}

module "cloud-nat" {
  count = length(local.regions)
  source = "../../modules/cloud-nat"
  region = local.regions[count.index]
  network = google_compute_network.network.name
  depends_on = [google_compute_network.network]
}

module "activedirectory" {
  source = "../../modules/activedirectory"
  regions = local.regions
  zones = local.zones
  network = google_compute_network.network.name
  subnetworks = [
    for subnet in google_compute_subnetwork.subnetworks:
    subnet.name
  ]
  name-domain = local.name-domain
  password = local.password
  depends_on = [module.cloud-nat]
}

module "bastion" {
  source = "../../modules/bastion-windows"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  machine-name = "bastion"
  password = local.password
  domain-name = local.name-domain
  enable-domain = true
  depends_on = [module.cloud-nat]
}


module "firewall-iap" {
  source = "../../modules/firewall-iap"
  network = google_compute_network.network.name
  enable-ssh = false
}

module "firewall-ad" {
  source = "../../modules/firewall-ad"
  name = "allow-ad-serverless"
  network = google_compute_network.network.name
  cidr-ranges = [
    local.network-range-serverless
  ]
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetworks" {
  count = length(local.regions)
  region = local.regions[count.index]
  name = local.regions[count.index]
  ip_cidr_range = local.network-ranges[count.index]
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    for range in local.network-ranges:
    range
  ]
}

resource "google_vpc_access_connector" "adjoin" {
  name = "adjoin"
  region = local.regions[0]
  ip_cidr_range = local.network-range-serverless
  network = google_compute_network.network.name
  depends_on = [module.apis]
}

resource "google_service_account" "adjoin" {
  account_id = "adjoin"
  display_name = "Service Account for adjoin operations"
}

resource "google_project_iam_binding" "adjoin-computeviewer" {
  role = "roles/compute.viewer"

  members = [
    "serviceAccount:${google_service_account.adjoin.email}",
  ]
}

resource "google_service_account_iam_binding" "cloudbuild-serviceaccountuser" {
  service_account_id = google_service_account.adjoin.name
  role = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
  ]
}

resource "google_project_iam_binding" "cloudbuild-runadmin" {
  role = "roles/run.admin"

  members = [
    "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
  ]
}

resource "google_secret_manager_secret" "adjoin" {
  secret_id = "adjoin"

  replication {
    automatic = true
  }

  provisioner "local-exec" {
    command = "printf '${local.password}' | gcloud secrets versions add ${google_secret_manager_secret.adjoin.secret_id} --data-file=-"
  }

  depends_on = [module.apis]
}

resource "google_secret_manager_secret_iam_binding" "binding" {
  secret_id = google_secret_manager_secret.adjoin.secret_id
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.adjoin.email}",
  ]
}

resource "google_cloud_run_service" "adjoin" {
  name = "adjoin"
  location = local.regions[0]

  template {
    spec {
      containers {
        image = "gcr.io/${data.google_project.project.name}/register-computer"
        
        env {
          name = "AD_DOMAIN"
          value = local.name-domain
        }
        
        env {
          name = "AD_USERNAME"
          value = "${split(".", local.name-domain)[0]}\\s-adjoiner"
        }

        env {
          name = "SECRET_PROJECT_ID"
          value = data.google_project.project.name
        }

        env {
          name = "SECRET_NAME"
          value = google_secret_manager_secret.adjoin.secret_id
        }

        env {
          name = "SECRET_VERSION"
          value = "latest"
        }

        env {
          name = "FUNCTION_IDENTITY"
          value = google_service_account.adjoin.email
        }

        env {
          name = "PROJECTS_DN"
          value = "OU=Projects,OU=${local.name-domain},DC=${join(",DC=", split(".", local.name-domain))}"
        }
      }

      service_account_name = google_service_account.adjoin.email
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "5"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.adjoin.self_link
        "run.googleapis.com/vpc-access-egress" = "all-traffic"
      }
    }
  }

  autogenerate_revision_name = true
}

resource "google_cloud_run_service_iam_binding" "adjoin" {
  service = google_cloud_run_service.adjoin.name
  location = google_cloud_run_service.adjoin.location
  
  role = "roles/run.invoker"
  members = [
    "allUsers",
  ]
}

resource "google_compute_instance_template" "adjoin" {
  count = length(local.image-families)
  name = split("/",local.image-families[count.index])[1]
  region = local.regions[0]
  machine_type = "n2-standard-4"

  tags = ["rdp"]

  disk {
    source_image = local.image-families[count.index]
    auto_delete = true
    boot = true
    disk_type = "pd-ssd"
    disk_size_gb = 100
  }

  network_interface {
    network = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnetworks[0].self_link
  }

  metadata = {
    sysprep-specialize-script-ps1 = "iex((New-Object System.Net.WebClient).DownloadString('${google_cloud_run_service.adjoin.status[0].url}'))"
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "adjoin" {
  count = length(local.image-families)
  name = split("/",local.image-families[count.index])[1]
  zone = local.zones[0]
  base_instance_name = split("/",local.image-families[count.index])[1]
  
  version {
    instance_template = google_compute_instance_template.adjoin[count.index].id
  }

  target_size = 0
}

resource "google_cloud_scheduler_job" "adjoin" {
  name = "adjoin"
  region = local.region-scheduler
  description = "Remove stale objects in Active Directory"
  schedule = "0 0 * * *"
  time_zone = "Europe/Berlin"

  retry_config {
    retry_count = 1
  }

  http_target {
    uri = "${google_cloud_run_service.adjoin.status[0].url}/cleanup"

    oidc_token {
      service_account_email = google_service_account.adjoin.email
      audience = "${google_cloud_run_service.adjoin.status[0].url}/"
    }
  }
}
