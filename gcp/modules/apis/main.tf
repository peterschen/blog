
locals {
}

resource "google_project_service" "apis" {
  count = length(var.apis)
  service = var.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}
