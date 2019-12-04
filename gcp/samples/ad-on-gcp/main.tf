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

resource "google_compute_firewall" "allow-rdp" {
  name    = "allow-rdp"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction = "INGRESS"

  target_tags = ["rdp"]
}

resource "google_compute_instance" "dc" {
   name         = "dc"
   machine_type = "n1-standard-2"

  tags = ["sample-${var.name-sample}-dc", "rdp", "icmp"]

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
        password = var.password 
      })
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }

  # provisioner "file" {
  #   source      = "ad.ps1"
  #   destination = "c:/bootstrap"

  #   connection {
  #     type     = "winrm"
  #     user     = "Administrator"
  #     password = "${var.password}"
  #     host     = "${self.network_interface.0.access_config.0.nat_ip}"
  #   }
  # }
}
