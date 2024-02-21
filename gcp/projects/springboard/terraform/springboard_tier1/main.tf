locals {
  org_id = var.org_id
  folder_id = var.folder_id
  billing_account = var.billing_account
  project_name = var.project_name
  project_suffix = var.project_suffix

  # APIs that are required
  core_apis = []

  # Constraints that are always enforced
  core_constraints = [
    {
      constraint = "iam.allowedPolicyMemberDomains"
      type = "list"
      enforce = null
      allowed_values = [
        "is:principalSet://iam.googleapis.com/organizations/${local.org_id}"
      ]
      denied_values = []
    },
    {
      constraint = "compute.requireShieldedVm"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "compute.vmCanIpForward"
      type = "list"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "compute.disableSerialPortAccess"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "storage.publicAccessPrevention"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "storage.uniformBucketLevelAccess"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    },
  ]

  # Merge core APIs with allowed APIs
  allowed_apis = concat(local.core_apis, var.allowed_apis)
  allowed_regions = var.allowed_regions

  # Merge core constraints with constraints passed as variable
  constraints = concat(local.core_constraints, var.constraints)

  peer_networks = var.peer_networks
  shared_networks = var.shared_networks
}

module "springboard" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/terraform/modules/springboard_core"
  org_id = local.org_id
  folder_id = local.folder_id
  billing_account = local.billing_account
  project_name = local.project_name
  project_suffix = local.project_suffix

  allowed_apis = local.allowed_apis
  allowed_regions = local.allowed_regions

  constraints = local.constraints

  peer_networks = local.peer_networks
  shared_networks = local.shared_networks
}
