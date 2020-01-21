provider "google" {
  version = "~> 3.4"
}

locals {
  project = var.project
}

resource "google_project_service" "apis" {
  project = local.project
  count = length(var.apis)
  service = var.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}
