locals {
  org_id = var.org_id
  billing_account = var.billing_account
  folder = var.folder

  prefix = "vmm"
}

module "folder" {
  source = "../../modules/folder"

  org_id = var.org_id
  prefix = local.prefix
}

module "project" {
  source = "../../modules/project"
  count = 5

  folder_id = module.folder.id
  billing_account = var.billing_account
  prefix = local.prefix

  apis = [
    "osconfig.googleapis.com"
  ]
}

data "google_projects" "projects" {
  filter = "parent.type:folder parent.id:${module.folder.id} lifecycle_state:ACTIVE"
}

resource "google_os_config_os_policy_assignment" "demo" {
  count = length(data.google_projects.projects.projects)
  name = "demo"
  project = data.google_projects.projects.projects[count.index].project_id
  location = "europe-west4-a"

  instance_filter {
    all = false

    inclusion_labels {
      labels = {
        demo = "value"
      }
    }
  }

  os_policies {
    id = "demo-policy"
    mode = "VALIDATION"

    resource_groups {
      resources {
        id = "script"

        exec {
          enforce {
            interpreter = "SHELL"
            script = "exit 100"
          }

          validate {
            interpreter = "SHELL"
            script = "exit 100"
          }
        }
      }
    }

    allow_no_resource_group_match = true
  }

  rollout {
    disruption_budget {
      fixed = 1
    }

    min_wait_duration = "3.5s"
  }
}
