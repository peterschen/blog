provider "google" {
  version = "~> 3.1"
  project = var.project
}

provider "google-beta" {
  version = "~> 3.1"
  project = var.project
}

locals {
  project = var.project
  regions = var.regions
  zones = var.zones
  name-domain = var.name-domain
  password = var.password
  network = var.network
  subnetworks = var.subnetworks
}

module "apis" {
  source = "github.com/peterschen/blog//gcp/modules/apis"
  project = local.project
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
}

module "gce-default-scopes" {
  source = "github.com/peterschen/blog//gcp/modules/gce-default-scopes"
}

module "sysprep" {
  source = "github.com/peterschen/blog//gcp/modules/sysprep"
}

resource "google_compute_address" "dc" {
  count = length(local.zones)
  region = local.regions[count.index]
  subnetwork = local.subnetworks[count.index].self_link
  name = "dc"
  address_type = "INTERNAL"
  address = cidrhost(local.subnetworks[count.index].ip_cidr_range, 2)
}

resource "google_compute_firewall" "allow-all-dc" {
  name    = "allow-all-dc"
  network = local.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_tags = ["ad"]
  target_tags = ["ad"]
}

resource "google_compute_firewall" "allow-dns-gcp" {
  name    = "allow-dns-gcp"
  network = local.network.name
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

resource "google_dns_managed_zone" "ad-dns-forward" {
  provider = google-beta
  name = "ad-dns-forward"
  dns_name = "${local.name-domain}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = local.network.self_link
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = google_compute_address.dc[0].address
    }
    target_name_servers {
      ipv4_address = google_compute_address.dc[1].address
    }
  }

  depends_on = [module.apis]
}

resource "google_compute_instance" "dc" {
  count = length(local.zones)
  zone = local.zones[count.index]
  name = "dc-${count.index}"
  machine_type = "n1-standard-1"

  tags = ["ad", "rdp", "dns"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = local.network.self_link
    subnetwork = local.subnetworks[count.index].self_link
    network_ip = google_compute_address.dc[count.index].address
  }

  metadata = {
    type = "dc"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
        nameHost = "dc-${count.index}", 
        password = local.password,
        parametersConfiguration = jsonencode({
          domainName = local.name-domain,
          zone = local.zones[count.index]
          networkRange = local.subnetworks[count.index].ip_cidr_range,
          isFirst = (count.index == 0),
          inlineMeta = filebase64(module.sysprep.path-meta),
          inlineConfiguration = filebase64("${path.module}/dc.ps1"),
          modulesDsc = [
            {
              Name = "xDnsServer",
              Version = "1.16.0"
              Uri = "https://github.com/dsccommunity/xDnsServer/archive/v1.16.0.zip"
            }
          ]
        })
      })
  }

  service_account {
    scopes = module.gce-default-scopes.scopes
  }

  depends_on = [module.apis]
}
