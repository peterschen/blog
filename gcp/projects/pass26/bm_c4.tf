module "bm_c4" {
  for_each = {
    for entry in flatten([
      for configuration in local.bm_configurations_c4: 
        configuration if configuration.enabled == true
    ]): "${entry.machine_type}-vc${entry.visible_cores}-tc${entry.threads_per_core}" => entry
  }

  source = "./bm"

  org_id = var.org_id
  billing_account = var.billing_account
  project_id = local.project_id_bm_c4
  prefix = "bm-vc${each.value.visible_cores}-tc${each.value.threads_per_core}"

  region = local.region_bm_c4
  zones = [
    local.zone_bm_c4
  ]

  domain_name = local.domain_name
  password = var.password

  machine_type_bastion = "n4-highcpu-64"
  machine_type_sql = each.value.machine_type
  threads_per_core_sql = each.value.threads_per_core
  visible_cores_sql = each.value.visible_cores
  turbo_mode_sql = each.value.turbo_mode
}
