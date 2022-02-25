locals {
  project = var.project
  name = var.name
  network = var.network
  cidr_ranges = var.cidr_ranges
}

resource "google_compute_firewall" "sofs" {
  project = local.project
  name = local.name
  network = local.network.name
  priority = 1000

  allow {
    protocol = "udp"
    ports    = ["137", "138"]
  }

  allow {
    protocol = "tcp"
    ports    = ["139", "445"]
  }

  direction = "INGRESS"

  source_ranges = local.cidr_ranges

  target_tags = ["sofs"]
}
