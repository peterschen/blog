
locals {
  org_id = var.org_id
  folder = var.folder_id != null ? "folders/${var.folder_id}" : null
  billing_account = var.billing_account
  name = var.name
  prefix = var.prefix
}

resource "random_pet" "project" {
  count = local.name == null ? 1 : 0
  length = local.prefix == null ? 2 : 1
  prefix = local.prefix
}

resource "random_integer" "project" {
  count = local.name == null ? 1 : 0
  min = 1000
  max = 9999
}

resource "google_project" "project" {
  project_id = local.name != null ? local.name : "${random_pet.project[0].id}-${random_integer.project[0].id}"
  name = local.name != null ? local.name : "${random_pet.project[0].id}-${random_integer.project[0].id}"
  org_id = local.org_id
  folder_id = local.folder
  billing_account = local.billing_account

  auto_create_network = false

  labels = {
    "migration-center-store-region" = "europe-west1"
  }
}

resource "google_project_service" "apis" {
  count = length(var.apis)
  project = google_project.project.project_id
  service = var.apis[count.index]

  disable_dependent_services = true
  disable_on_destroy = false
}

resource "google_project_organization_policy" "vm_external_ip_access" {
  project = google_project.project.project_id
  constraint = "compute.vmExternalIpAccess"

  restore_policy {
    default = true
  }
}

resource "google_project_organization_policy" "vm_can_ip_forward" {
  project = google_project.project.project_id
  constraint = "compute.vmCanIpForward"

  restore_policy {
    default = true
  }
}

resource "google_project_organization_policy" "restrict_vpn_peer_ips" {
  project = google_project.project.project_id
  constraint = "compute.restrictVpnPeerIPs"

  restore_policy {
    default = true
  }
}

resource "google_project_organization_policy" "trusted_image_project" {
  project = google_project.project.project_id
  constraint = "compute.trustedImageProjects"

  restore_policy {
    default = true
  }
}

resource "google_project_organization_policy" "allowed_policy_member_domains" {
  project = google_project.project.project_id
  constraint = "iam.allowedPolicyMemberDomains"

  restore_policy {
    default = true
  }
}

resource "google_project_organization_policy" "disable_service_account_key_creation" {
  project = google_project.project.project_id
  constraint = "iam.disableServiceAccountKeyCreation"

  restore_policy {
    default = true
  }
}
