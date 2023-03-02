resource "google_compute_ha_vpn_gateway" "onprem" {
  project = module.project_onprem.id
  region = local.region_vpn
  name = "onprem"
  network = google_compute_network.onprem.id
}

resource "google_compute_ha_vpn_gateway" "cloud" {
  project = module.project_cloud.id
  region = local.region_vpn
  name = "cloud"
  network = google_compute_network.cloud.id
}

resource "google_compute_router" "onprem" {
  project = module.project_onprem.id
  region = local.region_vpn
  name = "cloud"
  network = google_compute_network.onprem.name

  bgp {
    asn = 64515
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_router" "cloud" {
  project = module.project_cloud.id
  region = local.region_vpn
  name = "cloud"
  network = google_compute_network.cloud.name

  bgp {
    asn = 64516
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_vpn_tunnel" "onprem" {
  project = module.project_onprem.id
  region = local.region_vpn
  name = "onprem"
  
  vpn_gateway = google_compute_ha_vpn_gateway.onprem.id
  vpn_gateway_interface = 0
  peer_gcp_gateway = google_compute_ha_vpn_gateway.cloud.id
  shared_secret = local.password
  router = google_compute_router.onprem.id
}

resource "google_compute_vpn_tunnel" "cloud" {
  project = module.project_cloud.id
  region = local.region_vpn
  name = "cloud"
  
  vpn_gateway = google_compute_ha_vpn_gateway.cloud.id
  peer_gcp_gateway = google_compute_ha_vpn_gateway.onprem.id
  shared_secret = local.password
  router = google_compute_router.cloud.id
  vpn_gateway_interface = 0
}

resource "google_compute_router_interface" "onprem" {
  project = module.project_onprem.id
  region = local.region_vpn
  name = "onprem"
  router = google_compute_router.onprem.name
  ip_range = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.onprem.id
}

resource "google_compute_router_interface" "cloud" {
  project = module.project_cloud.id
  region = local.region_vpn
  name = "cloud"
  router = google_compute_router.cloud.name
  ip_range = "169.254.0.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.cloud.id
}

resource "google_compute_router_peer" "onprem" {
  project = module.project_onprem.id
  region = local.region_vpn
  name = "onprem"
  router = google_compute_router.onprem.name
  peer_ip_address = "169.254.0.2"
  peer_asn = 64516
  advertised_route_priority = 100
  interface = google_compute_router_interface.onprem.name
}

resource "google_compute_router_peer" "cloud" {
  project = module.project_cloud.id
  region = local.region_vpn
  name = "cloud"
  router = google_compute_router.cloud.name
  peer_ip_address = "169.254.0.1"
  peer_asn = 64515
  advertised_route_priority = 100
  interface = google_compute_router_interface.cloud.name
}
