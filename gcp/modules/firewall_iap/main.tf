locals {
  project = var.project
  network = var.network
  enable_rdp = var.enable_rdp
  enable_ssh = var.enable_ssh
}

resource "google_compute_firewall" "allow-rdp-iap" {
  count = local.enable_rdp ? 1 : 0

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
  count = local.enable_ssh ? 1 : 0
  
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
