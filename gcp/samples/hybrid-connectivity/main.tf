terraform {
  backend "gcs" {
    bucket = "cbp-tfstate"
    prefix = "s-hybrid-connectivity"
  }
}

provider "google" {
  project = "${var.project}"
}

data "google_client_config" "current" {}

resource "google_compute_network" "remote" {
  name                    = "remote"
  auto_create_subnetworks = false
}

resource "google_compute_network" "local" {
  name                    = "local"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "remote-subnet" {
  name                     = "remote-subnet"
  region                   = "${var.region_remote}"
  ip_cidr_range            = "10.10.0.0/24"
  network                  = "${google_compute_network.remote.self_link}"
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "local-subnet" {
  name                     = "local-subnet"
  region                   = "${var.region_local}"
  ip_cidr_range            = "10.20.0.0/24"
  network                  = "${google_compute_network.local.self_link}"
  private_ip_google_access = true
}

resource "google_compute_router" "remote-router" {
  name    = "remote-router"
  network = "${google_compute_network.remote.self_link}"
  region  = "${var.region_remote}"
  bgp {
    asn = 64515
  }
}

resource "google_compute_router" "local-router" {
  name    = "local-router"
  network = "${google_compute_network.local.self_link}"
  region  = "${var.region_local}"
  bgp {
    asn = 64516
  }
}

resource "google_compute_vpn_gateway" "remote-vpn" {
  name    = "remote-vpn"
  network = "${google_compute_network.remote.self_link}"
  region  = "${var.region_remote}"
}

resource "google_compute_vpn_gateway" "local-vpn" {
  name    = "local-vpn"
  network = "${google_compute_network.local.self_link}"
  region  = "${var.region_local}"
}

resource "google_compute_address" "remote-vpn-ip" {
  name   = "remote-vpn-ip"
  region = "${var.region_remote}"
}

resource "google_compute_address" "local-vpn-ip" {
  name   = "local-vpn-ip"
  region = "${var.region_local}"
}

resource "google_compute_forwarding_rule" "remote-esp" {
  name        = "remote-esp"
  ip_protocol = "ESP"
  ip_address  = "${google_compute_address.remote-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.remote-vpn.self_link}"
  region      = "${var.region_remote}"
}

resource "google_compute_forwarding_rule" "local-esp" {
  name        = "local-esp"
  ip_protocol = "ESP"
  ip_address  = "${google_compute_address.local-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.local-vpn.self_link}"
  region      = "${var.region_local}"
}

resource "google_compute_forwarding_rule" "remote-udp500" {
  name        = "remote-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = "${google_compute_address.remote-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.remote-vpn.self_link}"
  region      = "${var.region_remote}"
}

resource "google_compute_forwarding_rule" "local-udp500" {
  name        = "local-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = "${google_compute_address.local-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.local-vpn.self_link}"
  region      = "${var.region_local}"
}

resource "google_compute_forwarding_rule" "remote-udp4500" {
  name        = "remote-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = "${google_compute_address.remote-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.remote-vpn.self_link}"
  region      = "${var.region_remote}"
}

resource "google_compute_forwarding_rule" "local-udp4500" {
  name        = "local-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = "${google_compute_address.local-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.local-vpn.self_link}"
  region      = "${var.region_local}"
}

resource "google_compute_vpn_tunnel" "remote-local" {
  name          = "remote-local"
  peer_ip       = "${google_compute_address.local-vpn-ip.address}"
  shared_secret = "L9tncZDNhUR7gmDuriLVWE9Hju8GpORq"

  target_vpn_gateway = "${google_compute_vpn_gateway.remote-vpn.self_link}"
  router             = "${google_compute_router.remote-router.self_link}"

  depends_on = [
    "google_compute_forwarding_rule.remote-esp",
    "google_compute_forwarding_rule.remote-udp500",
    "google_compute_forwarding_rule.remote-udp4500",
  ]
}

resource "google_compute_vpn_tunnel" "local-remote" {
  name          = "local-remote"
  peer_ip       = "${google_compute_address.remote-vpn-ip.address}"
  shared_secret = "L9tncZDNhUR7gmDuriLVWE9Hju8GpORq"

  target_vpn_gateway = "${google_compute_vpn_gateway.local-vpn.self_link}"
  router             = "${google_compute_router.local-router.self_link}"

  depends_on = [
    "google_compute_forwarding_rule.local-esp",
    "google_compute_forwarding_rule.local-udp500",
    "google_compute_forwarding_rule.local-udp4500",
  ]
}

resource "google_compute_router_interface" "remote-interface" {
  name       = "remote-interface"
  router     = "${google_compute_router.remote-router.name}"
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = "${google_compute_vpn_tunnel.remote-local.self_link}"
  region     = "${var.region_remote}"
}

resource "google_compute_router_interface" "local-interface" {
  name       = "local-interface"
  router     = "${google_compute_router.local-router.name}"
  ip_range   = "169.254.0.2/30"
  vpn_tunnel = "${google_compute_vpn_tunnel.local-remote.self_link}"
  region     = "${var.region_local}"
}

resource "google_compute_router_peer" "remote-bgp" {
  name            = "remote-bgp"
  router          = "${google_compute_router.remote-router.name}"
  peer_ip_address = "169.254.0.2"
  peer_asn        = "64516"
  interface       = "${google_compute_router_interface.remote-interface.name}"
  region          = "${var.region_remote}"
}

resource "google_compute_router_peer" "local-bgp" {
  name            = "local-bgp"
  router          = "${google_compute_router.local-router.name}"
  peer_ip_address = "169.254.0.1"
  peer_asn        = "64515"
  interface       = "${google_compute_router_interface.local-interface.name}"
  region          = "${var.region_local}"
}

resource "google_compute_firewall" "remote" {
  name    = "allow-ssh"
  network = "${google_compute_network.remote.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"
}

resource "google_compute_firewall" "local" {
  name    = "allow-ssh"
  network = "${google_compute_network.local.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"
}
