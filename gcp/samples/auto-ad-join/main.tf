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
  cloudIdentityDomain = var.cloudIdentityDomain
  password = var.password

  # If ADFS is requested we need a CA
  enableCertificateAuthority = var.enableCertificateAuthority || var.enableAdfs ? true : false
  enableAdfs = var.enableAdfs
  enableDirectorySync = var.enableDirectorySync

  network-prefixes = ["10.0.0", "10.1.0"]
  network-mask = 16
  network-ranges = [
    for prefix in local.network-prefixes:
    "${prefix}.0/${local.network-mask}"
  ]
  network-range-adjoin = "10.8.0.0/28"
  network-range-directorysync = "10.9.0.0/28"
  ip-dcs = [
    for prefix in local.network-prefixes:
    "${prefix}.2"
  ]

  image-families = [
    "gce-uefi-images/windows-1809-core",
    "gce-uefi-images/windows-1809-core-for-containers",
    "gce-uefi-images/windows-1903-core",
    "gce-uefi-images/windows-1903-core-for-containers",
    "gce-uefi-images/windows-1909-core",
    "gce-uefi-images/windows-1909-core-for-containers",
    "windows-cloud/windows-2012-r2",
    "windows-cloud/windows-2012-r2-core",
    "windows-cloud/windows-2016",
    "windows-cloud/windows-2016-core",
    "windows-cloud/windows-2019-core-for-containers",
    "windows-cloud/windows-2019",
    "windows-cloud/windows-2019-core",
    "windows-cloud/windows-2019-for-containers",
    "windows-cloud/windows-20h2-core",
    "windows-cloud/windows-2022",
    "windows-cloud/windows-2022-core"
  ]
}

data "google_project" "project" {}

data "google_compute_default_service_account" "default" {}

data "google_compute_image" "windows" {
  count = length(local.image-families)
  project = split("/",local.image-families[count.index])[0]
  family = split("/",local.image-families[count.index])[1]
}

module "apis" {
  source = "../../modules/apis"
  apis = [
    "appengine.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "vpcaccess.googleapis.com",
    "dataconnectors.googleapis.com"
  ]
}

module "nat" {
  count = length(local.regions)
  source = "../../modules/nat"
  region = local.regions[count.index]
  network = google_compute_network.network.name
  depends_on = [google_compute_network.network]
}

module "ad" {
  source = "../../modules/ad"
  regions = local.regions
  zones = local.zones
  network = google_compute_network.network.name
  subnetworks = [
    for subnet in google_compute_subnetwork.subnetworks:
    subnet.name
  ]
  domain_name = local.name-domain
  password = local.password
  depends_on = [module.nat]
}

module "adcs" {
  count = local.enableCertificateAuthority ? 1 : 0
  source = "../../modules/adcs"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  nameDomain = local.name-domain
  password = local.password
  depends_on = [module.ad]
}

module "adfs" {
  count = local.enableAdfs ? 1 : 0
  source = "../../modules/adfs"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  nameDomain = local.name-domain
  cloudIdentityDomain = local.cloudIdentityDomain
  password = local.password
  depends_on = [module.ad]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  region = local.regions[0]
  zone = local.zones[0]
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name
  machine-name = "bastion"
  password = local.password
  domain-name = local.name-domain
  enable-domain = true
  depends_on = [module.ad]
}

module "firewall-iap" {
  source = "../../modules/firewall-iap"
  network = google_compute_network.network.name
  enable-ssh = false
}

module "firewall_ad" {
  source = "../../modules/firewall_ad"
  name = "allow-ad-serverless"
  network = google_compute_network.network.name
  cidr-ranges = [
    local.network-range-adjoin,
    local.network-range-directorysync
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
  ip_cidr_range = local.network-range-adjoin
  network = google_compute_network.network.name
  depends_on = [module.apis]
}

resource "google_vpc_access_connector" "directorysync" {
  count = local.enableDirectorySync ? 1 : 0
  name = "directorysync"
  region = "europe-west1"
  ip_cidr_range = local.network-range-directorysync
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

resource "google_secret_manager_secret" "adjoin_adpassword" {
  secret_id = "adjoin-adpassword"

  replication {
    automatic = true
  }

  provisioner "local-exec" {
    command = "printf '${local.password}' | gcloud secrets versions add ${google_secret_manager_secret.adjoin_adpassword.secret_id} --data-file=-"
  }

  depends_on = [module.apis]
}

resource "google_secret_manager_secret" "adjoin_cacert" {
  secret_id = "adjoin-cacert"

  replication {
    automatic = true
  }

  depends_on = [module.apis]
}

resource "google_secret_manager_secret_iam_binding" "adjoin_adpassword" {
  secret_id = google_secret_manager_secret.adjoin_adpassword.secret_id
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.adjoin.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "adjoin_cacert" {
  secret_id = google_secret_manager_secret.adjoin_cacert.secret_id
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
          name = "USE_LDAPS"
          value = local.enableCertificateAuthority
        }

        env {
          name = "SM_PROJECT"
          value = data.google_project.project.name
        }

        env {
          name = "SM_NAME_ADPASSWORD"
          value = google_secret_manager_secret.adjoin_adpassword.secret_id
        }

        env {
          name = "SM_VERSION_ADPASSWORD"
          value = "latest"
        }

        env {
          name = "SM_NAME_CACERT"
          value = google_secret_manager_secret.adjoin_cacert.secret_id
        }

        env {
          name = "SM_VERSION_CACERT"
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
  name_prefix = "${data.google_compute_image.windows[count.index].family}-"
  region = local.regions[0]
  machine_type = "n2-standard-4"

  tags = ["rdp"]

  disk {
    source_image = data.google_compute_image.windows[count.index].self_link
    auto_delete = true
    boot = true
    disk_type = "pd-ssd"
    disk_size_gb = 100
  }

  network_interface {
    network = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnetworks[0].self_link
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
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
  name = data.google_compute_image.windows[count.index].family
  zone = local.zones[0]
  base_instance_name = data.google_compute_image.windows[count.index].family
  
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
