locals {
  name = var.name
  network = var.network
  cidr-ranges = var.cidr-ranges
}

resource "google_compute_firewall" "sofs" {
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

  source_ranges = local.cidr-ranges

  target_tags = ["sofs"]
}
