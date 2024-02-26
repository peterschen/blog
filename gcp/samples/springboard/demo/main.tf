locals {
  org_id = var.org_id
  billing_account = var.billing_account
  project_name = var.project_name
  project_suffix = var.project_suffix

  allowed_regions = var.allowed_regions

  subnets = var.subnets
  peer_networks = var.peer_networks
}

module "springboard" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/springboard_tier1"
  org_id = local.org_id
  billing_account = local.billing_account
  project_name = local.project_name
  project_suffix = local.project_suffix

  allowed_regions = local.allowed_regions

  subnets = local.subnets
  peer_networks = local.peer_networks
}

resource "google_compute_instance_template" "vm_with_external_ip" {
  count = length(local.allowed_regions)
  project = module.springboard.project_name
  name = "vm-with-external-ip"
  region = local.allowed_regions[count.index]
  machine_type = "c3-standard-4"

  disk {
    source_image = "windows-cloud/windows-2022"
    auto_delete = true
    boot = true
    disk_type = "pd-ssd"
    disk_size_gb = 100
  }

  network_interface {
    network = module.springboard.network_id
    subnetwork = module.springboard.subnet_ids[0]

    # Empty block to ensure public IP is assigned
    access_config {}
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  service_account {
    email = "default"
    scopes = []
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "vm_without_external_ip" {
  count = length(local.allowed_regions)
  project = module.springboard.project_id
  name = "vm-without-external-ip"
  region = local.allowed_regions[count.index]
  machine_type = "c3-standard-4"

  disk {
    source_image = "windows-cloud/windows-2022"
    auto_delete = true
    boot = true
    disk_type = "pd-ssd"
    disk_size_gb = 100
  }

  network_interface {
    network = module.springboard.network_id
    subnetwork = module.springboard.subnet_ids[0]
  }

  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm = true
    enable_integrity_monitoring = true
  }

  service_account {
    email = "default"
    scopes = []
  }

  lifecycle {
    create_before_destroy = true
  }
}
