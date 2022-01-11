locals {
  project = var.project
  namePrefix = var.namePrefix
  network = var.network
  cidrRanges = var.cidrRanges
}

resource "google_compute_firewall" "ca-root" {
  project = local.project
  name = "${local.namePrefix}-ca-root"
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

  target_tags = ["ca-root"]
}
