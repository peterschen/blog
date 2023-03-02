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
  sample_name = "streched-sql-ag"

  region_onprem = var.region_onprem
  region_cloud = var.region_cloud
  region_vpn = var.region_vpn

  zone_onprem = var.zone_onprem
  zone_cloud = var.zone_cloud

  
  domain_name = var.domain_name
  password = var.password

  windows_image = "windows-cloud/windows-2022"
  windows_core_image = "windows-cloud/windows-2022-core"

  network_range_onprem = "10.0.0.0/16"
  network_range_cloud = "10.10.0.0/16"

  machine_type = "n2-standard-4"
  machine_type_dc = "n2-highcpu-2"
  machine_type_bastion = "n2-standard-4"

  count_nodes = 2
}

module "project_onprem" {
  source = "../../modules/project"

  prefix = "onprem"
  org_id = var.org_id
  billing_account = var.billing_account

  apis = [
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "dns.googleapis.com"
  ]
}

module "project_cloud" {
  source = "../../modules/project"

  prefix = "cloud"
  org_id = var.org_id
  billing_account = var.billing_account

  apis = [
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "dns.googleapis.com"
  ]
}

module "sysprep" {
  source = "../../modules/sysprep"
}

data "google_compute_default_service_account" "onprem" {
  project = module.project_onprem.id
}

data "google_compute_default_service_account" "cloud" {
  project = module.project_onprem.id
}

module "ad" {
  source = "../../modules/ad"
  project = module.project_onprem.id

  regions = [local.region_onprem]
  zones = [local.zone_onprem]

  network = google_compute_network.onprem.name
  subnetworks = [google_compute_subnetwork.onprem.name]

  domain_name = local.domain_name
  machine_type = local.machine_type_dc

  windows_image = local.windows_core_image

  password = local.password
  enable_ssl = false

  depends_on = [
    module.nat_onprem
  ]
}

module "bastion" {
  source = "../../modules/bastion_windows"
  project = module.project_onprem.id

  region = local.region_onprem
  zone = local.zone_onprem

  network = google_compute_network.onprem.name
  subnetwork = google_compute_subnetwork.onprem.name

  machine_type = local.machine_type_bastion
  machine_name = "bastion"

  windows_image = local.windows_image

  domain_name = local.domain_name
  password = local.password

  enable_domain = true

  depends_on = [
    module.ad
  ]
}

resource "google_compute_address" "dns" {
  project = module.project_cloud.id
  region = local.region_cloud
  subnetwork = google_compute_subnetwork.cloud.id
  name = "dns"
  address_type = "INTERNAL"
  address = cidrhost(google_compute_subnetwork.cloud.ip_cidr_range, 100)
}

resource "google_compute_address" "cluster_onprem" {
  count = local.count_nodes
  project = module.project_onprem.id
  region = local.region_onprem
  subnetwork = google_compute_subnetwork.onprem.self_link
  name = "cluster-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "cluster_cloud" {
  count = local.count_nodes
  project = module.project_cloud.id
  region = local.region_cloud
  subnetwork = google_compute_subnetwork.cloud.self_link
  name = "cluster-${count.index}"
  address_type = "INTERNAL"
}

resource "google_compute_address" "cluster_cl_onprem" {
  region = local.region_onprem
  project = module.project_onprem.id
  name = "cluster-cl"
  address_type = "INTERNAL"
  subnetwork = google_compute_subnetwork.onprem.self_link
}

resource "google_compute_address" "cluster_cl_cloud" {
  region = local.region_cloud
  project = module.project_cloud.id
  name = "cluster-cl"
  address_type = "INTERNAL"
  subnetwork = google_compute_subnetwork.cloud.self_link
}

resource "google_compute_address" "cluster_sql_onprem" {
  region = local.region_onprem
  project = module.project_onprem.id
  name = "cluster-sql"
  address_type = "INTERNAL"
  subnetwork = google_compute_subnetwork.onprem.self_link
}

resource "google_compute_address" "cluster_sql_cloud" {
  region = local.region_cloud
  project = module.project_cloud.id
  name = "cluster-sql"
  address_type = "INTERNAL"
  subnetwork = google_compute_subnetwork.cloud.self_link
}

resource "google_dns_managed_zone" "cloud" {
  project = module.project_cloud.id
  name = "onprem-through-dns-relay"
  dns_name = "${local.domain_name}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.cloud.id
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = google_compute_address.dns.address
    }
  }
}

resource "google_compute_instance" "dns" {
  project = module.project_cloud.id
  zone = local.zone_cloud
  name = "dns"
  machine_type = "e2-medium"

  tags = ["ssh", "dns"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      type = "pd-balanced"
    }
  }

  can_ip_forward = true
  network_interface {
    network = google_compute_network.cloud.id
    subnetwork = google_compute_subnetwork.cloud.id
    network_ip = google_compute_address.dns.address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    startup-script=<<-EOM
      #!/usr/bin/env bash

      set +eux

      apt-get install unbound -y

      cat <<- EOF > /etc/unbound/unbound.conf.d/${local.domain_name}.conf
        server:
          verbosity: 3
          interface: 0.0.0.0
          interface: ::0

          access-control: 0.0.0.0/0 allow	

          domain-insecure: "${local.domain_name}."
          
          forward-zone:
            name: "${local.domain_name}."
            %{ for ip in module.ad.address }
            forward-addr: ${ip}
            %{ endfor }
      EOF

      systemctl restart unbound
    EOM
  }

  allow_stopping_for_update = true  
}

resource "google_compute_instance" "node_onprem" {
  count = local.count_nodes
  project = module.project_onprem.id
  zone = local.zone_onprem
  name = "node-onprem-${count.index}"
  machine_type = local.machine_type

  tags = ["cluster", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.onprem.self_link
    subnetwork = google_compute_subnetwork.onprem.self_link
    network_ip = google_compute_address.cluster_onprem[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "node-onprem-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/cluster.ps1"),
          domainName = local.domain_name,
          isFirst = (count.index == 0),
          nodePrefix = "cluster",
          nodeCount = local.count_nodes,
          enableCluster = true,
          ipCluster = [google_compute_address.cluster_cl_onprem.address],
          modulesDsc = [
            {
              Name = "xFailOverCluster",
              Version = "1.16.0"
            }
          ]
        })
      })
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  lifecycle {
    ignore_changes = [
      attached_disk
    ]
  }

  allow_stopping_for_update = true

  depends_on = [
    module.ad
  ]
}

resource "google_compute_instance" "node_cloud" {
  count = local.count_nodes
  project = module.project_cloud.id
  zone = local.zone_cloud
  name = "node-cloud-${count.index}"
  machine_type = local.machine_type

  tags = ["cluster", "rdp"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.cloud.self_link
    subnetwork = google_compute_subnetwork.cloud.self_link
    network_ip = google_compute_address.cluster_cloud[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-wsfc = "true"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "node-cloud-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/cluster.ps1"),
          domainName = local.domain_name,
          isFirst = false, # Cluster creation will be done onprem
          nodePrefix = "cluster",
          nodeCount = local.count_nodes,
          enableCluster = true,
          ipCluster = google_compute_address.cluster_cl_cloud.address,
          modulesDsc = [
            {
              Name = "xFailOverCluster",
              Version = "1.16.0"
            }
          ]
        })
      })
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  lifecycle {
    ignore_changes = [
      attached_disk
    ]
  }

  allow_stopping_for_update = true

  depends_on = [
    module.ad
  ]
}

resource "google_compute_disk" "node_onprem" {
  for_each = { for index, value in google_compute_instance.node_onprem: index => value }
  project = module.project_onprem.id
  zone = each.value.zone
  name = "cluster-data-${each.key}"
  type = "pd-balanced"
  size = 50
}

resource "google_compute_disk" "node_cloud" {
  for_each = { for index, value in google_compute_instance.node_cloud: index => value }
  project = module.project_cloud.id
  zone = each.value.zone
  name = "cluster-data-${each.key}"
  type = "pd-balanced"
  size = 50
}

resource "google_compute_attached_disk" "node_onprem" {
  for_each = { for index, value in google_compute_instance.node_onprem: index => value }
  project = module.project_onprem.id
  disk = google_compute_disk.node_onprem[each.key].self_link
  instance = each.value.self_link
}

resource "google_compute_attached_disk" "node_cloud" {
  for_each = { for index, value in google_compute_instance.node_cloud: index => value }
  project = module.project_cloud.id
  disk = google_compute_disk.node_cloud[each.key].self_link
  instance = each.value.self_link
}
