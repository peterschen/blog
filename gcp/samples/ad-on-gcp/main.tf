terraform {
  required_providers {
    google = {
      version = "~> 3.1"
    }
  }
}

provider "google" {
}

provider "google-beta" {
}

locals {
  prefix = var.prefix
  regions = var.regions
  zones = var.zones
  region_scheduler = var.region_scheduler
  sample_name = "ad-on-gcp"
  
  domain_name = var.domain_name
  password = var.password

  windows_image = var.windows_image
  windows_core_image = var.windows_core_image

  cloud_identity_domain = var.cloud_identity_domain

  # If ADFS is requested we need a CA
  enable_adjoin = var.enable_adjoin
  enable_adcs = var.enable_adcs || var.enable_adfs ? true : false
  enable_adfs = var.enable_adfs
  enable_directorysync = var.enable_directorysync
  enable_discoveryclient = var.enable_discoveryclient

  network_prefixes = ["10.0.0", "10.1.0"]
  network_prefixes_proxy_lb = ["10.6.0", "10.7.0"]

  network_mask = 16
  network_mask_proxy_lb = 23

  network_ranges = [
    for prefix in local.network_prefixes:
    "${prefix}.0/${local.network_mask}"
  ]
  network_ranges_proxy_lb = [
    for prefix in local.network_prefixes_proxy_lb:
    "${prefix}.0/${local.network_mask_proxy_lb}"
  ]

  network_range_adjoin = "10.8.0.0/28"
  network_range_directorysync = "10.9.0.0/28"
  ips_dcs = [
    for prefix in local.network_prefixes:
    "${prefix}.2"
  ]

  machine_type_dc = "n2-highcpu-2"
  machine_type_ca = "n2-highcpu-2"
  machine_type_bastion = "n2-standard-4"
  machine_type_adjoin = "n2-highcpu-2"
  machine_type_joinvm = "e2-medium"

  # Number of vCPU in VM * 7 workers + 1
  server_workers = 2 * 7 + 1

  adjoin_container_uri = var.adjoin_container_uri

  image_families = [
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
    "windows-cloud/windows-2022",
    "windows-cloud/windows-2022-core"
  ]
}

module "project" {
  source = "../../modules/project"

  org_id = var.org_id
  billing_account = var.billing_account

  prefix = local.prefix

  apis = [
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "vpcaccess.googleapis.com",
    "dataconnectors.googleapis.com",
    "migrationcenter.googleapis.com",
    "rapidmigrationassessment.googleapis.com"
  ]
}

data "google_compute_default_service_account" "default" {
  project = module.project.id
}

data "google_compute_image" "windows" {
  count = local.enable_adjoin ? length(local.image_families) : 0
  project = split("/",local.image_families[count.index])[0]
  family = split("/",local.image_families[count.index])[1]
}

resource "google_compute_network" "network" {
  project = module.project.id
  name = local.sample_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetworks" {
  count = length(local.regions)
  project = module.project.id
  region = local.regions[count.index]
  name = local.regions[count.index]
  ip_cidr_range = local.network_ranges[count.index]
  network = google_compute_network.network.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "proxy_lb" {
  provider = google-beta
  count = length(local.regions)
  project = module.project.id
  region = local.regions[count.index]

  name = "lb-${local.regions[count.index]}"
  ip_cidr_range = local.network_ranges_proxy_lb[count.index]
  network = google_compute_network.network.id
  purpose = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}

module "nat" {
  count = length(local.regions)
  source = "../../modules/nat"
  project = module.project.id

  region = local.regions[count.index]
  network = google_compute_network.network.name

  depends_on = [
    google_compute_network.network
  ]
}

module "ad" {
  source = "../../modules/ad"
  project = module.project.id

  regions = local.regions
  zones = local.zones

  network = google_compute_network.network.name
  subnetworks = [
    for subnet in google_compute_subnetwork.subnetworks:
    subnet.name
  ]

  domain_name = local.domain_name
  machine_type = local.machine_type_dc

  windows_image = local.windows_core_image

  password = local.password
  enable_ssl = local.enable_adcs

  depends_on = [
    module.nat
  ]
}

module "adcs" {
  count = local.enable_adcs ? 1 : 0
  source = "../../modules/adcs"
  project = module.project.id

  region = local.regions[0]
  zone = local.zones[0]

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name

  machine_type = local.machine_type_ca
  windows_image = local.windows_core_image

  domain_name = local.domain_name
  password = local.password
  
  depends_on = [
    module.ad
  ]
}

module "adfs" {
  count = local.enable_adfs ? 1 : 0
  source = "../../modules/adfs"
  project = module.project.id

  region = local.regions[0]
  zone = local.zones[0]
  
  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name

  windows_image = local.windows_core_image

  domain_name = local.domain_name
  password = local.password

  cloud_identity_domain = local.cloud_identity_domain
  
  depends_on = [
    module.ad
  ]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  project = module.project.id

  region = local.regions[0]
  zone = local.zones[0]

  network = google_compute_network.network.name
  subnetwork = google_compute_subnetwork.subnetworks[0].name

  machine_type = local.machine_type_bastion
  machine_name = "bastion"

  windows_image = local.windows_image

  domain_name = local.domain_name
  password = local.password

  enable_domain = true
  enable_discoveryclient = local.enable_discoveryclient

  depends_on = [
    module.ad
  ]
}

module "firewall_iap" {
  source = "../../modules/firewall_iap"
  project = module.project.id
  network = google_compute_network.network.name
  enable_ssh = false
}

module "firewall_ad" {
  source = "../../modules/firewall_ad"
  project = module.project.id
  name = "allow-ad-serverless"
  network = google_compute_network.network.name

  cidr_ranges = [
    local.network_range_adjoin,
    local.network_range_directorysync
  ]
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  project = module.project.id

  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [
    for range in local.network_ranges:
    range
  ]
}

resource "google_compute_firewall" "allow-adjoin-healthcheck" {
  name = "allow-adjoin-healthcheck"
  project = module.project.id

  network = google_compute_network.network.id
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  direction = "INGRESS"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags = [
    "adjoin"
  ]
}

resource "google_compute_firewall" "allow-adjoin-lb" {
  name    = "allow-adjoin-lb"
  project = module.project.id

  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  direction = "INGRESS"

  source_ranges = [
    for range in local.network_ranges_proxy_lb:
    range
  ]

  target_tags = [
    "adjoin"
  ]
}

resource "google_vpc_access_connector" "adjoin" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id
  
  name = "adjoin"
  region = local.regions[0]
  
  ip_cidr_range = local.network_range_adjoin
  network = google_compute_network.network.name

  # Explicit dependeny as API enablement takes a little longer
  depends_on = [
    module.project
  ]
}

resource "google_vpc_access_connector" "directorysync" {
  count = local.enable_directorysync ? 1 : 0
  project = module.project.id

  name = "directorysync"
  region = "europe-west1"
  
  ip_cidr_range = local.network_range_directorysync
  network = google_compute_network.network.name

  # Explicit dependeny as API enablement takes a little longer
  depends_on = [
    module.project
  ]
}

resource "google_service_account" "adjoin" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  account_id = "adjoin"
  display_name = "Service Account for adjoin operations"
}

resource "google_service_account" "migration_center" {
  count = local.enable_discoveryclient ? 1 : 0
  project = module.project.id

  account_id = "migration-center"
  display_name = "Service Account for Migration Center operations"
}

resource "google_project_iam_binding" "adjoin_computeviewer" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  role = "roles/compute.viewer"

  members = [
    "serviceAccount:${google_service_account.adjoin[0].email}",
  ]
}

resource "google_service_account_iam_binding" "cloudbuild_serviceaccountuser" {
  count = local.enable_adjoin ? 1 : 0

  service_account_id = google_service_account.adjoin[0].name
  role = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:${module.project.number}@cloudbuild.gserviceaccount.com",
  ]

  depends_on = [
    module.project
  ]
}

resource "google_project_iam_binding" "cloudbuild_runadmin" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  role = "roles/run.admin"

  members = [
    "serviceAccount:${module.project.number}@cloudbuild.gserviceaccount.com",
  ]

  depends_on = [
    module.project
  ]
}

resource "google_secret_manager_secret" "adjoin_adpassword" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  secret_id = "adjoin-adpassword"

  replication {
    automatic = true
  }

  provisioner "local-exec" {
    command = "printf '${local.password}' | gcloud secrets versions add --project ${module.project.id} ${google_secret_manager_secret.adjoin_adpassword[0].secret_id} --data-file=-"
  }

  depends_on = [
    module.project
  ]
}

resource "google_secret_manager_secret" "adjoin_cacert" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  secret_id = "adjoin-cacert"

  replication {
    automatic = true
  }

  depends_on = [
    module.project
  ]
}

resource "google_secret_manager_secret_iam_binding" "adjoin_adpassword" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  secret_id = google_secret_manager_secret.adjoin_adpassword[0].secret_id
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.adjoin[0].email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "adjoin_cacert" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  secret_id = google_secret_manager_secret.adjoin_cacert[0].secret_id
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.adjoin[0].email}",
  ]
}

resource "google_cloud_run_service" "adjoin" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  name = "adjoin"
  location = local.regions[0]

  template {
    spec {
      containers {
        image = local.adjoin_container_uri
        
        env {
          name = "AD_DOMAIN"
          value = local.domain_name
        }
        
        env {
          name = "AD_USERNAME"
          value = "${split(".", local.domain_name)[0]}\\s-adjoiner"
        }

        env {
          name = "USE_LDAPS"
          value = "${local.enable_adcs}"
        }

        env {
          name = "SM_PROJECT"
          value = module.project.name
        }

        env {
          name = "SM_NAME_ADPASSWORD"
          value = google_secret_manager_secret.adjoin_adpassword[0].secret_id
        }

        env {
          name = "SM_VERSION_ADPASSWORD"
          value = "latest"
        }

        env {
          name = "SM_NAME_CACERT"
          value = google_secret_manager_secret.adjoin_cacert[0].secret_id
        }

        env {
          name = "SM_VERSION_CACERT"
          value = "latest"
        }

        env {
          name = "FUNCTION_IDENTITY"
          value = google_service_account.adjoin[0].email
        }

        env {
          name = "PROJECTS_DN"
          value = "OU=Projects,OU=${local.domain_name},DC=${join(",DC=", split(".", local.domain_name))}"
        }
      }

      service_account_name = google_service_account.adjoin[0].email
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "5"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.adjoin[0].id
        "run.googleapis.com/vpc-access-egress" = "all-traffic"
      }
    }
  }

  autogenerate_revision_name = true
}

resource "google_cloud_run_service_iam_binding" "adjoin" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  service = google_cloud_run_service.adjoin[0].name
  location = google_cloud_run_service.adjoin[0].location
  
  role = "roles/run.invoker"
  members = [
    "allUsers",
  ]
}

resource "google_compute_instance_template" "joinvm" {
  count = local.enable_adjoin ? length(local.image_families) : 0
  project = module.project.id

  name_prefix = "${data.google_compute_image.windows[count.index].family}-"
  region = local.regions[0]
  machine_type = local.machine_type_joinvm

  tags = ["rdp"]

  disk {
    source_image = data.google_compute_image.windows[count.index].id
    auto_delete = true
    boot = true
    disk_type = "pd-ssd"
    disk_size_gb = 100
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetworks[0].id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = "iex((New-Object System.Net.WebClient).DownloadString('${google_cloud_run_service.adjoin[0].status[0].url}'))"
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "joinvm" {
  count = local.enable_adjoin ? length(local.image_families) : 0
  project = module.project.id

  name = data.google_compute_image.windows[count.index].family
  zone = local.zones[0]
  base_instance_name = data.google_compute_image.windows[count.index].family
  
  version {
    instance_template = google_compute_instance_template.joinvm[count.index].id
  }

  target_size = 0
}

resource "google_cloud_scheduler_job" "adjoin" {
  count = local.enable_adjoin ? 1 : 0
  project = module.project.id

  name = "adjoin"
  region = local.region_scheduler
  description = "Remove stale objects in Active Directory"
  schedule = "0 0 * * *"
  time_zone = "Europe/Berlin"

  retry_config {
    retry_count = 1
  }

  http_target {
    uri = "${google_cloud_run_service.adjoin[0].status[0].url}/cleanup"
    http_method = "POST"

    oidc_token {
      service_account_email = google_service_account.adjoin[0].email
      audience = "${google_cloud_run_service.adjoin[0].status[0].url}/"
    }
  }
}

resource "google_compute_instance_template" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name_prefix = "adjoin"
  machine_type = local.machine_type_adjoin

  tags = ["ssh", "adjoin"]

  disk {
    source_image = "cos-cloud/cos-stable"
    auto_delete = true
    boot = true
    disk_type = "pd-balanced"
    disk_size_gb = 10
  }

  network_interface {
    network = google_compute_network.network.id
    subnetwork = google_compute_subnetwork.subnetworks[count.index].id
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "true"
    gce-container-declaration = <<-EOM
      spec:
        containers:
        - name: adjoin-n2-highcpu-8-57procs-v1
          image: gcr.io/cbpetersen-sandbox/adjoin
          env:
          - name: AD_DOMAIN
            value: ${local.domain_name}
          - name: AD_USERNAME
            value: ${split(".", local.domain_name)[0]}\\s-adjoiner
          - name: USE_LDAPS
            value: '${local.enable_adcs}'
          - name: SM_PROJECT
            value: ${module.project.name}
          - name: SM_NAME_ADPASSWORD
            value: ${google_secret_manager_secret.adjoin_adpassword[0].secret_id}
          - name: SM_VERSION_ADPASSWORD
            value: latest
          - name: SM_NAME_CACERT
            value: ${google_secret_manager_secret.adjoin_cacert[0].secret_id}
          - name: SM_VERSION_CACERT
            value: latest
          - name: FUNCTION_IDENTITY
            value: ${google_service_account.adjoin[0].email}
          - name: PROJECTS_DN
            value: OU=Projects,OU=${local.domain_name},DC=${join(",DC=", split(".", local.domain_name))}
          - name: PORT
            value: '8080'
          - name: SERVER_WORKERS
            value: '${local.server_workers}'
          stdin: false
          tty: false
          restartPolicy: OnFailure
      EOM
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  name = "adjoin-${local.regions[count.index]}"
  region = local.regions[count.index]
  base_instance_name = "adjoin"
  
  version {
    instance_template = google_compute_instance_template.adjoin[count.index].id
  }

  named_port {
    name = "adjoin"
    port = 8080
  }

  target_size = 0
}

resource "google_compute_region_health_check" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  timeout_sec = 2
  check_interval_sec = 2

  http_health_check {
    port = 8080
  }
}

resource "google_compute_region_backend_service" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  
  load_balancing_scheme = "INTERNAL_MANAGED"

  protocol = "HTTP"
  port_name = "adjoin"
  timeout_sec = 30
  health_checks = [google_compute_region_health_check.adjoin[count.index].id]

  backend {
    group = google_compute_region_instance_group_manager.adjoin[count.index].instance_group
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  default_service = google_compute_region_backend_service.adjoin[count.index].id
}

resource "google_compute_region_target_http_proxy" "adjoin" {
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  url_map = google_compute_region_url_map.adjoin[count.index].id
}

resource "google_compute_forwarding_rule" "adjoin" {
  provider = google-beta
  count = length(local.regions)
  project = module.project.id

  region = local.regions[count.index]
  name = "adjoin-${local.regions[count.index]}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  
  
  port_range = "8080"
  target = google_compute_region_target_http_proxy.adjoin[count.index].id
  network = google_compute_network.network.id
  subnetwork = google_compute_subnetwork.subnetworks[count.index].id

  # Explicit dependency required so things can be desotryed properly
  depends_on = [
    google_compute_subnetwork.proxy_lb
  ]
}
