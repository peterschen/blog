
locals {
  org_id = var.org_id
  prefix = var.prefix
}

resource "random_pet" "folder" {
  length = local.prefix == null ? 2 : 1
  prefix = local.prefix
}

resource "google_folder" "folder" {
  parent = "organizations/${local.org_id}"
  display_name = "${random_pet.folder.id}"
}
