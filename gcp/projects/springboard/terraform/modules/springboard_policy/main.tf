
locals {
  project_name = var.project_name
  constraints = var.constraints
}

module "org-policy" {
  source = "terraform-google-modules/org-policy/google"
  version = "~> 5.3.0"

  count = length(local.constraints)

  policy_for = "project"
  constraint = "constraints/${local.constraints[count.index].constraint}"
  policy_type = local.constraints[count.index].type
  project_id = local.project_name
  
  enforce = local.constraints[count.index].enforce
  allow = local.constraints[count.index].allowed_values
  deny = local.constraints[count.index].denied_values

  allow_list_length = length(local.constraints[count.index].allowed_values)
  deny_list_length = length(local.constraints[count.index].denied_values)
}