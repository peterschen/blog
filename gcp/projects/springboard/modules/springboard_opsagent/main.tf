
locals {
  project_name = var.project_name
  regions = var.regions
}

module "opsagent-regional" {
  count = length(local.regions)
  source = "./modules/opsagent_regional"
  project_name = local.project_name
  region = local.regions[count.index]
}

resource "google_compute_project_metadata_item" "osconfig" {
  project = local.project_name
  key = "enable-osconfig"
  value = "true"
}
