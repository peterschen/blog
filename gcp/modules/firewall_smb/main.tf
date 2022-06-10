locals {
  project = var.project
  name = var.name
  network = var.network
  cidr_ranges = var.cidr_ranges
}

data "google_project" "network" {
  project_id = local.project
}

data "google_compute_network" "network" {
  project = data.google_project.network.project_id
  name = local.network
}

resource "google_compute_firewall" "allow_smb" {
  project = data.google_project.network.project_id
  name = local.name
  network = data.google_compute_network.network.name
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

  target_tags = ["smb"]
}
