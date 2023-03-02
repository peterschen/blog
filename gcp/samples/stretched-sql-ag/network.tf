resource "google_compute_network" "onprem" {
  project = module.project_onprem.id
  name = local.sample_name
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
}

resource "google_compute_network" "cloud" {
  project = module.project_cloud.id
  name = local.sample_name
  auto_create_subnetworks = false
  routing_mode = "GLOBAL"
}

resource "google_compute_subnetwork" "onprem" {
  project = module.project_onprem.id
  region = local.region_onprem
  name = local.region_onprem
  ip_cidr_range = local.network_range_onprem
  network = google_compute_network.onprem.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "cloud" {
  project = module.project_cloud.id
  region = local.region_cloud
  name = local.region_cloud
  ip_cidr_range = local.network_range_cloud
  network = google_compute_network.cloud.id
  private_ip_google_access = true
}

module "nat_onprem" {
  source = "../../modules/nat"
  project = module.project_onprem.id

  region = local.region_onprem
  network = google_compute_network.onprem.name
}

module "nat_cloud" {
  source = "../../modules/nat"
  project = module.project_cloud.id

  region = local.region_cloud
  network = google_compute_network.cloud.name
}