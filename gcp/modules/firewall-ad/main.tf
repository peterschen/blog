locals {
  name = var.name
  network = var.network
  cidr-ranges = var.cidr-ranges
}

resource "google_compute_firewall" "activedirectory" {
  name = local.name
  network = local.network
  priority = 1000

  allow {
    protocol = "udp"
    ports    = ["88", "123", "389", "445", "464"]
  }

  allow {
    protocol = "tcp"
    ports    = ["88", "135", "389", "445", "464", "636", "3268", "3269", "9389", "49152-65535"]
  }

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"

  source_ranges = local.cidr-ranges

  target_tags = ["ad"]
}
