
locals {
  project_name = var.project_name
  region = var.region

  region_zone_map = {
    "africa-south1": [
      "africa-south1-b",
      "africa-south1-a",
      "africa-south1-c"
    ],
    "asia-east1": [
      "asia-east1-a",
      "asia-east1-b",
      "asia-east1-c"
    ],
    "asia-east2": [
      "asia-east2-c",
      "asia-east2-b",
      "asia-east2-a"
    ],
    "asia-northeast1": [
      "asia-northeast1-a",
      "asia-northeast1-b",
      "asia-northeast1-c"
    ],
    "asia-northeast2": [
      "asia-northeast2-b",
      "asia-northeast2-c",
      "asia-northeast2-a"
    ],
    "asia-northeast3": [
      "asia-northeast3-a",
      "asia-northeast3-c",
      "asia-northeast3-b"
    ],
    "asia-south1": [
      "asia-south1-b",
      "asia-south1-a",
      "asia-south1-c"
    ],
    "asia-south2": [
      "asia-south2-a",
      "asia-south2-c",
      "asia-south2-b"
    ],
    "asia-southeast1": [
      "asia-southeast1-a",
      "asia-southeast1-b",
      "asia-southeast1-c"
    ],
    "asia-southeast2": [
      "asia-southeast2-a",
      "asia-southeast2-c",
      "asia-southeast2-b"
    ],
    "australia-southeast1": [
      "australia-southeast1-c",
      "australia-southeast1-a",
      "australia-southeast1-b"
    ],
    "australia-southeast2": [
      "australia-southeast2-a",
      "australia-southeast2-c",
      "australia-southeast2-b"
    ],
    "europe-central2": [
      "europe-central2-b",
      "europe-central2-c",
      "europe-central2-a"
    ],
    "europe-north1": [
      "europe-north1-b",
      "europe-north1-c",
      "europe-north1-a"
    ],
    "europe-southwest1": [
      "europe-southwest1-b",
      "europe-southwest1-a",
      "europe-southwest1-c"
    ],
    "europe-west1": [
      "europe-west1-b",
      "europe-west1-c",
      "europe-west1-d"
    ],
    "europe-west10": [
      "europe-west10-c",
      "europe-west10-a",
      "europe-west10-b"
    ],
    "europe-west12": [
      "europe-west12-c",
      "europe-west12-a",
      "europe-west12-b"
    ],
    "europe-west2": [
      "europe-west2-a",
      "europe-west2-b",
      "europe-west2-c"
    ],
    "europe-west3": [
      "europe-west3-c",
      "europe-west3-a",
      "europe-west3-b"
    ],
    "europe-west4": [
      "europe-west4-c",
      "europe-west4-b",
      "europe-west4-a"
    ],
    "europe-west6": [
      "europe-west6-b",
      "europe-west6-c",
      "europe-west6-a"
    ],
    "europe-west8": [
      "europe-west8-a",
      "europe-west8-b",
      "europe-west8-c"
    ],
    "europe-west9": [
      "europe-west9-b",
      "europe-west9-a",
      "europe-west9-c"
    ],
    "me-central1": [
      "me-central1-a",
      "me-central1-b",
      "me-central1-c"
    ],
    "me-central2": [
      "me-central2-c",
      "me-central2-a",
      "me-central2-b"
    ],
    "me-west1": [
      "me-west1-b",
      "me-west1-a",
      "me-west1-c"
    ],
    "northamerica-northeast1": [
      "northamerica-northeast1-a",
      "northamerica-northeast1-b",
      "northamerica-northeast1-c"
    ],
    "northamerica-northeast2": [
      "northamerica-northeast2-b",
      "northamerica-northeast2-a",
      "northamerica-northeast2-c"
    ],
    "southamerica-east1": [
      "southamerica-east1-a",
      "southamerica-east1-b",
      "southamerica-east1-c"
    ],
    "southamerica-west1": [
      "southamerica-west1-a",
      "southamerica-west1-b",
      "southamerica-west1-c"
    ],
    "us-central1": [
      "us-central1-a",
      "us-central1-b",
      "us-central1-c",
      "us-central1-f"
    ],
    "us-east1": [
      "us-east1-b",
      "us-east1-c",
      "us-east1-d"
    ],
    "us-east4": [
      "us-east4-a",
      "us-east4-b",
      "us-east4-c"
    ],
    "us-east5": [
      "us-east5-c",
      "us-east5-b",
      "us-east5-a"
    ],
    "us-south1": [
      "us-south1-c",
      "us-south1-a",
      "us-south1-b"
    ],
    "us-west1": [
      "us-west1-a",
      "us-west1-b",
      "us-west1-c"
    ],
    "us-west2": [
      "us-west2-c",
      "us-west2-b",
      "us-west2-a"
    ],
    "us-west3": [
      "us-west3-a",
      "us-west3-b",
      "us-west3-c"
    ],
    "us-west4": [
      "us-west4-c",
      "us-west4-a",
      "us-west4-b"
    ]
  }
}

resource "google_os_config_os_policy_assignment" "ensure_opsagent_windows" {
  count = length(local.region_zone_map[local.region])

  project = local.project_name
  location = local.region_zone_map[local.region][count.index]
  name = "ensure-opsagent-windows"
  description = "Ensuring OpsAgent is deployed on Windows instances in ${local.region_zone_map[local.region][count.index]}"

  instance_filter {
    all = false
    
    inventories {
      os_short_name = "windows"
    }
  }

  os_policies {
    id = "install-opsagent"
    mode = "ENFORCEMENT"

    resource_groups {
      resources {
        id = "add-repository"
        repository {
          goo {
            name = "google-cloud-ops-agent-windows-all"
            url = "https://packages.cloud.google.com/yuck/repos/google-cloud-ops-agent-windows-all"
          }
        }
      }

      resources {
        id = "install-package"

        pkg {
          desired_state = "INSTALLED"

          googet {
            name = "google-cloud-ops-agent"
          }
        }
      }

      resources {
        id = "ensure-agent-running"
        exec {
          validate {
            interpreter = "POWERSHELL"
            script = <<-EOS
              $state = Get-Service -Name "google-cloud-ops-agent"
              if ($state.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
              {
                exit 100
              }
              else
              {
                exit 101
              }
            EOS
          }

          enforce {
            interpreter = "POWERSHELL"
            script = <<-EOS
              try
              {
                Start-Service -Name google-cloud-ops-agent
                exit 100
              }
              except
              {
                exit 101
              }
            EOS
          }
        }
      }
    }
  }

  rollout {
    disruption_budget {
      fixed = 1
    }

    min_wait_duration = "60s"
  }
}
