
locals {
  org_id = var.org_id
  folder = var.folder_id != null ? "folders/${var.folder_id}" : null
  billing_account = var.billing_account
  name = var.name
}

resource "random_pet" "project" {
  count = local.name == null ? 1 : 0
  length = 2
}

resource "random_integer" "project" {
  count = local.name == null ? 1 : 0
  min = 1000
  max = 9999
}

resource "google_project" "project" {
  project_id = local.name != null ? local.name : "${element(random_pet.project, 0).id}-${element(random_integer.project, 0).id}"
  name = local.name != null ? local.name : "${element(random_pet.project, 0).id}-${element(random_integer.project, 0).id}"
  org_id = local.org_id
  folder_id = local.folder
  billing_account = local.billing_account

  auto_create_network = false
}

resource "google_project_service" "apis" {
  count = length(var.apis)
  project = google_project.project.project_id
  service = var.apis[count.index]

  disable_dependent_services = true
  disable_on_destroy = false
}
