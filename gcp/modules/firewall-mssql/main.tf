locals {
  project = var.project
  name = var.name
  network = var.network
  cidr-ranges = var.cidr-ranges
}

resource "google_compute_firewall" "sqlserver" {
  project = local.project
  name = local.name
  network = local.network.name
  priority = 1000

  allow {
    protocol = "udp"
    ports    = ["1434"]
  }

  allow {
    protocol = "tcp"
    ports    = ["1433", "1434"]
  }

  direction = "INGRESS"

  source_ranges = local.cidr-ranges

  target_tags = ["mssql"]
}
