locals {
  org_id = var.org_id
  folder_id = var.folder_id
  billing_account = var.billing_account
  project_name = var.project_name

  # APIs that are required
  core_apis = []

  # Constraints that are always enforced
  core_constraints = []

  # Merge core APIs with allowed APIs
  allowed_apis = concat(local.core_apis, var.allowed_apis)
  allowed_regions = var.allowed_regions

  # Merge core constraints with constraints passed as variable
  constraints = concat(local.core_constraints, var.constraints)
}

module "springboard" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/terraform/modules/springboard_core"
  org_id = local.org_id
  folder_id = local.folder_id
  billing_account = local.billing_account
  project_name = local.project_name

  allowed_apis = local.allowed_apis
  allowed_regions = local.allowed_regions

  constraints = local.constraints
}
