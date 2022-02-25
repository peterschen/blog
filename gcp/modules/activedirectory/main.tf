locals {
  regions = var.regions
  zones = var.zones
  name_domain = var.name-domain
  password = var.password
  network = var.network
  subnetworks = var.subnetworks
  machine-type = var.machine-type
}

data "google_project" "project" {}

data "google_compute_network" "network" {
  name = local.network
}

data "google_compute_subnetwork" "subnetworks" {
  count = length(local.subnetworks)
  region = local.regions[count.index]
  name = local.subnetworks[count.index]
}

module "apis" {
  # source = "github.com/peterschen/blog//gcp/modules/apis"
  source = "../apis"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
}

module "gce-default-scopes" {
  # source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
  source = "../gce-default-scopes"
}

module "sysprep" {
  # source = "github.com/peterschen/blog//gcp/modules/sysprep"
  source = "../sysprep"
}

module "firewall-ad" {
  # source = "github.com/peterschen/blog//gcp/modules/firewall-ad"
  source = "../firewall-ad"
  name = "allow-ad"
  network = data.google_compute_network.network.self_link
  cidr-ranges = [
    for subnet in data.google_compute_subnetwork.subnetworks:
    subnet.ip_cidr_range
  ]
}

resource "google_compute_address" "dc" {
  count = length(local.zones)
  region = local.regions[count.index]
  subnetwork = data.google_compute_subnetwork.subnetworks[count.index].self_link
  name = "dc"
  address_type = "INTERNAL"
  address = cidrhost(data.google_compute_subnetwork.subnetworks[count.index].ip_cidr_range, 2)
}

resource "google_compute_firewall" "allow-dns-gcp" {
  name = "allow-dns-gcp"
  network = data.google_compute_network.network.self_link
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

resource "google_compute_firewall" "allow-dns-internal" {
  name = "allow-dns-internal"
  network = data.google_compute_network.network.self_link
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

resource "google_dns_managed_zone" "ad-dns-forward" {
  name = "ad-dns-forward"
  dns_name = "${local.name_domain}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = data.google_compute_network.network.self_link
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

  depends_on = [module.apis]
}

resource "google_compute_instance" "dc" {
  count = length(local.zones)
  zone = local.zones[count.index]
  name = "dc-${count.index}"
  machine_type = local.machine-type

  tags = ["ad", "rdp", "dns"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.network.self_link
    subnetwork = data.google_compute_subnetwork.subnetworks[count.index].self_link
    network_ip = google_compute_address.dc[count.index].address
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  metadata = {
    type = "dc"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize-nupkg, { 
        nameHost = "dc-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          "projectName" = data.google_project.project.name,
          domainName = local.name_domain,
          zone = local.zones[count.index],
          zones = local.zones,
          networkRange = data.google_compute_subnetwork.subnetworks[count.index].ip_cidr_range,
          isFirst = (count.index == 0),
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/dc.ps1"),
          modulesDsc = [
            {
              Name = "xDnsServer",
              Version = "2.0.0"
            }
          ]
        })
      })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  allow_stopping_for_update = true

  depends_on = [module.apis]
}
