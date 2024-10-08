locals {
  project = var.project
  project_network = var.project_network == null ? var.project : var.project_network

  regions = var.regions
  zones = var.zones
  
  network = var.network
  subnetworks = var.subnetworks
  
  domain_name = var.domain_name
  password = var.password
  
  machine_type = var.machine_type
  windows_image = var.windows_image

  enable_ssl = var.enable_ssl
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

data "google_compute_subnetwork" "subnetworks" {
  count = length(local.regions)
  project = data.google_project.network.project_id
  region = local.regions[count.index]
  name = local.subnetworks[count.index]
}

module "apis" {
  source = "../apis"
  project = data.google_project.default.project_id
  apis = [
    "compute.googleapis.com",
    "dns.googleapis.com"
  ]
}

module "firewall_ad" {
  source = "../firewall_ad"
  project = data.google_project.network.project_id
  name = "allow-ad"
  network = data.google_compute_network.network.id

  cidr_ranges = [
    for subnet in data.google_compute_subnetwork.subnetworks:
    subnet.ip_cidr_range
  ]
}

resource "google_compute_firewall" "allow_dns_gcp" {
  project = data.google_project.network.project_id

  name = "allow-dns-gcp"
  network = data.google_compute_network.network.id
  priority = 5000

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  direction = "INGRESS"

  source_ranges = ["35.199.192.0/19"]

  target_tags = ["dns"]
}

resource "google_compute_firewall" "allow_dns_internal" {
  project = data.google_project.network.project_id
  name = "allow-dns-internal"
  network = data.google_compute_network.network.id
  priority = 5000

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  direction = "INGRESS"

  source_ranges = [
    for subnet in data.google_compute_subnetwork.subnetworks:
    subnet.ip_cidr_range
  ]

  target_tags = ["dns"]
}

resource "google_compute_address" "dc" {
  count = length(local.zones)
  project = data.google_project.network.project_id
  region = one(
    [
      for region in local.regions:
      region if strcontains(local.zones[count.index], region)
    ]
  )
  subnetwork = one(
    [
      for subnet in data.google_compute_subnetwork.subnetworks:
      subnet.id if strcontains(local.zones[count.index], subnet.region)
    ]
  )
  name = "dc-${count.index}"
  address_type = "INTERNAL"
}

module "gce_scopes" {
  source = "../gce_scopes"
}

module "sysprep" {
  source = "../sysprep"
}

resource "google_compute_instance" "dc" {
  count = length(local.zones)
  project = data.google_project.default.project_id
  zone = local.zones[count.index]
  name = "dc-${count.index}"
  machine_type = local.machine_type

  tags = ["ad", "rdp", "dns"]

  boot_disk {
    initialize_params {
      image = local.windows_image
      type = strcontains(local.machine_type, "n4") ? "hyperdisk-balanced" : "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.id
    subnetwork = one(
      [
        for subnet in data.google_compute_subnetwork.subnetworks:
        subnet.id if strcontains(local.zones[count.index], subnet.region)
      ]
    )
    network_ip = google_compute_address.dc[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path_specialize, { 
        nameHost = "dc-${count.index}"
        password = local.password,
        parametersConfiguration = jsonencode({
          projectName = data.google_project.default.name,
          domainName = local.domain_name,
          region = one(
            [
              for region in local.regions:
              region if strcontains(local.zones[count.index], region)
            ]
          ),
          regions = local.regions,
          networkRange = one(
            [
              for subnet in data.google_compute_subnetwork.subnetworks:
              subnet.ip_cidr_range if strcontains(local.zones[count.index], subnet.region)
            ]
          )
          isFirst = (count.index == 0),
          inlineMeta = filebase64(module.sysprep.path_meta),
          inlineConfiguration = filebase64("${path.module}/dc.ps1"),
          enableSsl = local.enable_ssl,
          modulesDsc = [
            {
              Name = "xDnsServer",
              Version = "2.0.0"
            },
            {
              Name = "CertificateDsc",
              Version = "5.1.0"
            }
          ]
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

resource "google_dns_managed_zone" "ad_dns_forward" {
  project = data.google_project.default.project_id
  name = "ad-dns-forward"
  dns_name = "${local.domain_name}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = data.google_compute_network.network.id
    }
  }

  forwarding_config {
    dynamic "target_name_servers" {
      for_each = google_compute_address.dc
      content {
        ipv4_address = target_name_servers.value.address
      }
    }
  }
}
