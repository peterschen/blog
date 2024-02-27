locals {
  org_id = var.org_id
  folder_id = var.folder_id
  billing_account = var.billing_account
  project_name = var.project_name
  project_suffix = var.project_suffix

  # APIs that are required
  core_apis = [
    "logging.googleapis.com",
    "osconfig.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "networksecurity.googleapis.com"
  ]

  # Constraints that are always enforced
  core_constraints = [
    {
      constraint = "gcp.restrictServiceUsage"
      type = "list"
      enforce = null # optional attributes are not available with TF 1.2.3
      allowed_values = local.allowed_apis
      denied_values = []
    },
    {
      constraint = "gcp.resourceLocations"
      type = "list"
      enforce = null # optional attributes are not available with TF 1.2.3
      allowed_values = [
        for region in local.allowed_regions:
            "in:${region}-locations"
      ]
      denied_values = []
    },
    {
      constraint = "iam.automaticIamGrantsForDefaultServiceAccounts"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "compute.skipDefaultNetworkCreation"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "compute.vmExternalIpAccess"
      type = "list"
      enforce = true
      allowed_values = []
      denied_values = []
    },
    {
      constraint = "iam.disableServiceAccountKeyCreation"
      type = "boolean"
      enforce = true
      allowed_values = []
      denied_values = []
    }
  ]

  core_firewall_rules = [
    {
      name = "deny-smtp-egress",
      priority = 50000
      disabled = false
      direction = "EGRESS"
      allow = [],
      deny = [
        {
          protocol = "tcp",
          ports = [
            "25"
          ]
        }
      ],
      source_tags = [],
      target_tags = [],
      source_ranges = [],
      destination_ranges = [
        "0.0.0.0/0"
      ],
      logging = true
    }
  ]

  # Merge core APIs with allowed APIs
  allowed_apis = concat(local.core_apis, var.allowed_apis)
  allowed_regions = var.allowed_regions

  # Merge core constraints with constraints passed in
  constraints = concat(local.core_constraints, var.constraints)

  subnets = var.subnets
  peer_networks = var.peer_networks
  shared_networks = var.shared_networks

  # Merge core firewall rules with firewall rules passed in
  firewall_rules = concat(local.core_firewall_rules, var.firewall_rules)
}

module "project" {
  source  = "github.com/peterschen/blog//gcp/projects/springboard/modules/springboard_project"
  org_id = local.org_id
  folder_id = local.folder_id
  billing_account = local.billing_account
  name = local.project_name
  suffix = local.project_suffix

  apis = local.allowed_apis
}

module "organization_policy" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/modules/springboard_policy"
  project_name = module.project.name
  constraints = local.constraints
}

module "opsagent" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/modules/springboard_opsagent"
  project_name = module.project.name
  regions = local.allowed_regions

  depends_on = [ 
    module.organization_policy
  ]
}

module "network" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/modules/springboard_network"
  project_name = module.project.name
  subnets = local.subnets
  peer_networks = local.peer_networks
  shared_networks = local.shared_networks
  
  depends_on = [ 
    module.organization_policy
  ]
}

module "firewall" {
  source = "github.com/peterschen/blog//gcp/projects/springboard/modules/springboard_firewall"
  project_name = module.project.name
  network_name = module.network.name
  network_id = module.network.id
  rules = local.firewall_rules

  depends_on = [ 
    module.organization_policy
  ]
}

data "google_compute_default_service_account" "compute_sa" {
  depends_on = [ 
    module.project
  ]
}

resource "google_project_iam_member" "compute_logwriter" {
  project = module.project.id
  role  = "roles/logging.logWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.compute_sa.email}"
}

resource "google_project_iam_member" "compute_metricwriter" {
  project = module.project.id
  role  = "roles/monitoring.metricWriter"
  member = "serviceAccount:${data.google_compute_default_service_account.compute_sa.email}"
}
