provider "google" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
  zone = "${var.zone}"
}

provider "google-beta" {
  version = "~> 3.1"
  project = "${var.project}"
  region = "${var.region}"
  zone = "${var.zone}"
}

locals {
  name-sample = "ad-on-gce"
  apis = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
  network-prefix = "10.10.0"
  network-mask = "24"
  network-range = "${local.network-prefix}.0/${local.network-mask}"
}

data "google_client_config" "current" {}

resource "google_project_service" "apis" {
  count = length(local.apis)
  
  service = "${local.apis[count.index]}"
  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_compute_network" "network" {
  name                    = "${local.name-sample}"
  auto_create_subnetworks = false

  depends_on = ["google_project_service.apis"]
}

resource "google_compute_subnetwork" "network-subnet" {
  name                     = "sn-${var.region}"
  ip_cidr_range            = "${local.network-range}"
  network                  = "${google_compute_network.network.self_link}"
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.network.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = "router-nat"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = "${google_compute_network.network.name}"
  priority = 1000

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = [local.network-range]
}

resource "google_compute_firewall" "allow-dns-gcp" {
  name    = "allow-dns-gcp"
  network = "${google_compute_network.network.name}"
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

resource "google_compute_firewall" "allow-rdp-gcp" {
  name    = "allow-rdp-gcp"
  network = "${google_compute_network.network.name}"
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["rdp"]
}

resource "google_dns_managed_zone" "ad-forward" {
  provider = "google-beta"
  name        = "ad-forward"
  dns_name    = "${var.name-domain}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.network.self_link
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = "${local.network-prefix}.2"
    }
  }

  depends_on = ["google_project_service.apis"]
}

resource "google_compute_instance" "dc" {
   name         = "dc"
   machine_type = "n1-standard-2"

  tags = ["sample-${local.name-sample}-dc", "rdp", "dns"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = "${google_compute_network.network.self_link}"
    subnetwork = "${google_compute_subnetwork.network-subnet.self_link}"
    network_ip = "${local.network-prefix}.2"
  }

  metadata = {
    sample                        = "${local.name-sample}"
    type                          = "dc"
    sysprep-specialize-script-ps1 = templatefile("${path.module}/specialize.ps1", { 
        nameHost = "dc", 
        nameDomain = var.name-domain,
        nameConfiguration = "ad",
        uriMeta = var.uri-meta,
        uriConfigurations = var.uri-configurations,
        password = var.password 
      })
  }

  depends_on = ["google_project_service.apis"]
}

resource "google_compute_instance" "jumpy" {
  name         = "jumpy"
  machine_type = "n1-standard-1"

  tags = ["sample-${local.name-sample}-jumpy", "rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = "${google_compute_network.network.self_link}"
    subnetwork = "${google_compute_subnetwork.network-subnet.self_link}"
    network_ip = "${local.network-prefix}.3"
  }

  metadata = {
    sample                        = "${local.name-sample}"
    type                          = "jumpy"
    sysprep-specialize-script-ps1 = templatefile("${path.module}/specialize.ps1", { 
      nameHost = "jumpy", 
      nameDomain = var.name-domain,
      nameConfiguration = "jumpy",
      uriMeta = var.uri-meta,
      uriConfigurations = var.uri-configurations,
      password = var.password 
    })
  }

  depends_on = ["google_project_service.apis"]
}
