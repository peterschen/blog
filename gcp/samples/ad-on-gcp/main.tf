terraform {
  backend "gcs" {
    bucket = "cbp-state"
    prefix = "s-ad-on-gcp"
  }
}

provider "google" {
  project = "${var.project}"
  region = "${var.region}"
  zone = "${var.zone}"
}

provider "google-beta" {
  project = "${var.project}"
  region = "${var.region}"
  zone = "${var.zone}"
}

data "google_client_config" "current" {}

resource "google_project_service" "apis" {
  count = length(var.apis)
  
  service = "${var.apis[count.index]}"
  disable_dependent_services = false
}

resource "google_compute_network" "network" {
  name                    = "${var.name-sample}"
  auto_create_subnetworks = false

  depends_on = ["google_project_service.apis"]
}

resource "google_compute_subnetwork" "network-subnet" {
  name                     = "sn-${var.region}"
  ip_cidr_range            = "10.10.0.0/24"
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

resource "google_compute_firewall" "allow-icmp" {
  name    = "allow-icmp"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"

  target_tags = ["icmp"]
}

resource "google_compute_firewall" "allow-dns-gcp" {
  name    = "allow-dns-gcp"
  network = "${google_compute_network.network.name}"

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
  target_tags = ["dns-gcp"]
}

resource "google_compute_firewall" "allow-rdp-iap" {
  name    = "allow-rdp-iap"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["rdp"]
}

resource "google_compute_firewall" "allow-all-internal" {
  name    = "allow-all-internal"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = ["10.10.0.0/24"]
}

resource "google_compute_instance" "dc" {
   name         = "dc"
   machine_type = "n1-standard-2"

  tags = ["sample-${var.name-sample}-dc", "rdp", "dns-gcp", "icmp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = "${google_compute_network.network.self_link}"
    subnetwork = "${google_compute_subnetwork.network-subnet.self_link}"
  }

  metadata = {
    sample                        = "${var.name-sample}"
    type                          = "dc"
    sysprep-specialize-script-ps1 = templatefile("specialize.ps1", { 
        nameHost = "dc", 
        nameDomain = var.name-domain,
        nameConfiguration = "ad",
        password = var.password 
      })
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_compute_instance" "jumpy" {
  name         = "jumpy"
  machine_type = "n1-standard-1"

  tags = ["sample-${var.name-sample}-jumpy", "rdp", "icmp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network = "${google_compute_network.network.self_link}"
    subnetwork = "${google_compute_subnetwork.network-subnet.self_link}"
  }

  metadata = {
    sample                        = "${var.name-sample}"
    type                          = "jumpy"
    sysprep-specialize-script-ps1 = templatefile("specialize.ps1", { 
      nameHost = "jumpy", 
      nameDomain = var.name-domain,
      nameConfiguration = "jumpy",
      password = var.password 
    })
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  depends_on = ["google_compute_instance.dc"]
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
      ipv4_address = google_compute_instance.dc.network_interface[0].network_ip
    }
  }
}

resource "google_dns_managed_zone" "ad-reverse" {
  provider = "google-beta"
  name        = "ad-reverse"
  dns_name    = "0.10.10.in-addr.arpa."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.network.self_link
    }
  }
}

resource "google_dns_record_set" "dc" {
  name = "${element(split(".", google_compute_instance.dc.network_interface[0].network_ip), 3)}.0.10.10.in-addr.arpa."
  type = "PTR"
  ttl  = 60

  managed_zone = google_dns_managed_zone.ad-reverse.name

  rrdatas = ["dc.${var.name-domain}."]
}

resource "google_dns_record_set" "jumpy" {
  name = "${element(split(".", google_compute_instance.jumpy.network_interface[0].network_ip), 3)}.0.10.10.in-addr.arpa."
  type = "PTR"
  ttl  = 60

  managed_zone = google_dns_managed_zone.ad-reverse.name

  rrdatas = ["jumpy.${var.name-domain}."]
}
