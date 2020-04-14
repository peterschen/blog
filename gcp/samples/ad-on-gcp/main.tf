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
  name-sample = "ad-on-gce"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
  scopes-default = ["https://www.googleapis.com/auth/cloud-platform"]
  network-prefixes = ["10.0.0", "10.1.0"]
  network-mask = 16
  network-ranges = ["${local.network-prefixes[0]}.0/${local.network-mask}", "${local.network-prefixes[1]}.0/${local.network-mask}"]
  ip-dcs = ["${local.network-prefixes[0]}.2", "${local.network-prefixes[1]}.2"]
}

module "sysprep" {
  source = "github.com/peterschen/blog//gcp/modules/sysprep"
}

module "firewall-iap" {
  source = "github.com/peterschen/blog//gcp/modules/firewall-iap"
  project = local.project
  network = google_compute_network.network
  enable-ssh = false
}

resource "google_project_service" "apis" {
  count = length(local.apis)
  service = local.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_compute_network" "network" {
  name = local.name-sample
  auto_create_subnetworks = false
  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnets" {
  count = length(var.regions)
  region = var.regions[count.index]
  name = var.regions[count.index]
  ip_cidr_range = local.network-ranges[count.index]
  network = google_compute_network.network.self_link
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  count = length(var.regions)
  region = var.regions[count.index]
  name = "router-${var.regions[count.index]}"
  network = google_compute_network.network.self_link
}

resource "google_compute_router_nat" "nat" {
  count = length(var.regions)
  region = var.regions[count.index]
  name = "nat"
  router = google_compute_router.router[count.index].name
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = google_compute_network.network.name
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [local.network-ranges[0], local.network-ranges[1]]
}

resource "google_compute_firewall" "allow-dns-gcp" {
  name    = "allow-dns-gcp"
  network = google_compute_network.network.name
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
  dns_name = "${var.name-domain}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.network.self_link
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = local.ip-dcs[0]
    }
    target_name_servers {
      ipv4_address = local.ip-dcs[1]
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_instance" "dc" {
  count = length(var.regions)
  zone = "${var.regions[count.index]}-${var.zones[count.index][0]}"
  name = "dc-${count.index}"
  machine_type = "n1-standard-1"

  tags = ["rdp", "dns"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnets[count.index].self_link
    network_ip = "${local.network-prefixes[count.index]}.2"
  }

  metadata = {
    sample = local.name-sample
    type = "dc"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
        nameHost = "dc-${count.index}", 
        uriMeta = var.uri-meta,
        password = var.password,
        parametersConfiguration = jsonencode({
          domainName = var.name-domain,
          zone = "${var.regions[count.index]}-${var.zones[count.index][0]}",
          networkRange = local.network-ranges[count.index],
          isFirst = (count.index == 0),
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
    scopes = local.scopes-default
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_instance" "jumpy" {
  name = "jumpy"
  zone = "${var.regions[0]}-${var.zones[0][0]}"
  machine_type = "n1-standard-2"

  tags = ["sample-${local.name-sample}-jumpy", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
      type = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnets[0].self_link
    network_ip = "${local.network-prefixes[0]}.3"
  }

  metadata = {
    sample = local.name-sample
    type = "jumpy"
    sysprep-specialize-script-ps1 = templatefile(module.sysprep.path-specialize, { 
      nameHost = "jumpy", 
      uriMeta = var.uri-meta,
      password = var.password,
      parametersConfiguration = jsonencode({
        domainName = var.name-domain,
        inlineConfiguration = filebase64("${path.module}/jumpy.ps1")
      })
    })
  }

  service_account {
    scopes = local.scopes-default
  }

  depends_on = [google_project_service.apis]
}
