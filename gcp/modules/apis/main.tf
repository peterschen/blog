
locals {
  project = var.project
}

resource "google_project_service" "apis" {
  count = length(var.apis)
  project = local.project
  service = var.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}
