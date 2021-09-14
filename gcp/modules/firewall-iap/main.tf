locals {
  project = var.project
  network = var.network
  enable-rdp = var.enable-rdp
  enable-ssh = var.enable-ssh
}

resource "google_compute_firewall" "allow-rdp-iap" {
  count = local.enable-rdp ? 1 : 0

  project = local.project
  name = "allow-rdp-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["rdp"]
}

resource "google_compute_firewall" "allow-ssh-iap" {
  count = local.enable-ssh ? 1 : 0
  
  project = local.project
  name = "allow-ssh-iap"
  network = local.network
  priority = 5000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]

  target_tags = ["ssh"]
}
