module "demo1" {
  count  = local.enable_demo1 ? 1 : 0
  source = "./demo"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_demo1
  prefix = "passdemo1"

  region = local.region_demo1
  zones = [
    local.zone_demo1
  ]

  domain_name = local.domain_name
  password = var.password
  enable_cluster = false

  machine_type_bastion = "n4-highcpu-4"
  machine_type_sql = "n4-highcpu-4"
}

resource "google_compute_project_metadata_item" "enable_osconfig" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  key = "enable-osconfig"
  value = "true"
}

resource "google_os_config_os_policy_assignment" "ops_agent_windows_demo1" {
  count = local.enable_demo1 ? 1 : 0
  project = module.demo1[count.index].project_id
  name = "ops-agent-windows"
  location = local.zone_demo1
  
  instance_filter {
    all = true
  }

  os_policies {
    id = "ops-agent-windows"
    mode = "ENFORCEMENT"
    allow_no_resource_group_match = true

    resource_groups {
      inventory_filters {
        os_short_name = "windows"
        os_version = "10.*"
      }

      inventory_filters {
        os_short_name = "windows"
        os_version = "6.*"
      }

      resources {
        id = "add-repo"

        repository {
          goo {
            name = "Google Cloud Ops Agent"
            url = "https://packages.cloud.google.com/yuck/repos/google-cloud-ops-agent-windows-all"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          googet {
            name = "google-cloud-ops-agent"
          }
        }
      }

      resources {
        id = "set-config"

        exec {
          validate {
            script = file("${path.module}/demo1_validate.ps1")
            interpreter = "POWERSHELL"
          }

          enforce {
            script = file("${path.module}/demo1_enforce.ps1")
            interpreter = "POWERSHELL"
          }
        }
      }
    }
  }

  rollout {
    min_wait_duration = "0s"

    disruption_budget {
      percent = 100
    }
  }
}
