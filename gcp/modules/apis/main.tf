provider "google" {
  version = "~> 3.4"
  project = var.project
  zone = var.zone
}

resource "google_project_service" "apis" {
  count = length(var.apis)
  service = var.apis[count.index]
  disable_dependent_services = true
  disable_on_destroy = false
}
