terraform {
  backend "gcs" {
    bucket = "cbp-tfstate"
    prefix = "minecraft-on-gke"
  }
}

variable "project" {
  default = "cbp-minecraft"
}

variable "region" {
  default = "europe-west3"
}

variable "zone" {
  default = "europe-west3-c"
}

variable "sample_name" {
  default = "minecraft-on-gke"
}

locals {
  network_name = "${var.sample_name}"
}

provider "google" {
  region = "${var.region}"
}

data "google_client_config" "current" {}

data "google_container_engine_versions" "default" {
  location = "${var.zone}"
}

resource "google_compute_network" "minecraft-on-gke" {
  name                    = "${local.network_name}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "minecraft-on-gke" {
  name                     = "${local.network_name}"
  ip_cidr_range            = "10.127.0.0/20"
  network                  = "${google_compute_network.minecraft-on-gke.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = true
}

resource "google_container_cluster" "minecraft-on-gke" {
  name               = "${var.sample_name}"
  location           = "${var.zone}"
  initial_node_count = 1
  min_master_version = "${data.google_container_engine_versions.default.latest_master_version}"
  network            = "${google_compute_network.minecraft-on-gke.name}"
  subnetwork         = "${google_compute_subnetwork.minecraft-on-gke.name}"

  provisioner "local-exec" {
    when    = "destroy"
    command = "sleep 90"
  }
}

output network {
  value = "${google_compute_subnetwork.minecraft-on-gke.network}"
}

output subnetwork_name {
  value = "${google_compute_subnetwork.minecraft-on-gke.name}"
}

output cluster_name {
  value = "${google_container_cluster.minecraft-on-gke.name}"
}

output cluster_region {
  value = "${var.region}"
}

output cluster_zone {
  value = "${google_container_cluster.minecraft-on-gke.zone}"
}
