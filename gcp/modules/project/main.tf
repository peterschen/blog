
locals {
  org_id = var.org_id
  billing_account = var.billing_account
}

resource "random_pet" "project" {
  length = 2
}

resource "random_integer" "project" {
  min = 1000
  max = 9999
}

resource "google_project" "project" {
  project_id = "${random_pet.project.id}-${random_integer.project.id}"
  name = "${random_pet.project.id}-${random_integer.project.id}"
  org_id = local.org_id
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

resource "google_project_organization_policy" "vm_external_ip_access" {
  project = google_project.project.project_id
  constraint = "compute.vmExternalIpAccess"

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
