locals {
  project = var.project
  name = var.name
  network = var.network
  cidrRanges = var.cidrRanges
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

  source_ranges = local.cidrRanges

  target_tags = ["ca"]
}
