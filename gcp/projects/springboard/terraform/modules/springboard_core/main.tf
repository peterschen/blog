locals {
  org_id = var.org_id
  folder_id = var.folder_id
  billing_account = var.billing_account
  project_name = var.project_name

  # APIs that are required
  core_apis = [
    "logging.googleapis.com",
    "osconfig.googleapis.com"
  ]

  # Constraints that are always enforced
  core_constraints = [
    {
      constraint = "gcp.restrictServiceUsage"
      type = "list"
      allowed_values = local.allowed_apis
      denied_values = []
    },
    {
      constraint = "gcp.resourceLocations"
      type = "list"
      allowed_values = [
        for region in local.allowed_regions:
            "in:${region}-locations"
      ]
      denied_values = []
    },
    {
      constraint = "iam.automaticIamGrantsForDefaultServiceAccounts"
      type = "boolean"
      enforced = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "compute.skipDefaultNetworkCreation"
      type = "boolean"
      enforced = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "compute.vmExternalIpAccess"
      type = "list"
      enforce = true
      allowed_values = []
      denied_values = []
    }
  ]

  # Merge core APIs with allowed APIs
  allowed_apis = concat(local.core_apis, var.allowed_apis)
  allowed_regions = var.allowed_regions

  # Merge core constraints with constraints passed as variable
  constraints = concat(local.core_constraints, var.constraints)
}

module "project" {
  source  = "github.com/peterschen/blog//gcp/projects/springboard/terraform/modules/springboard_project"
  version = "~> 1.0.0"

  org_id = local.org_id
  folder_id = local.folder_id
  billing_account = local.billing_account
  name = local.project_name

  apis = local.allowed_apis
}

module "organization_policy" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/terraform/modules/springboard_policy"
  version = "~> 1.0.0"

  project_name = module.project.name
  constraints = local.constraints
}

module "opsagent" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/terraform/modules/springboard_opsagent"
  version = "~> 1.0.0"

  project_name = module.project.name
  regions = local.allowed_regions
}