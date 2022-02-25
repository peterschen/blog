locals {
  project = var.project
  name = var.name
  network = var.network
  cidr_ranges = var.cidr_ranges
}

resource "google_compute_firewall" "ca" {
  project = local.project
  name = local.name
  network = local.network
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"

  source_ranges = local.cidr_ranges

  target_tags = ["ca"]
}
