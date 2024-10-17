output "project_id_demo5" {
  value = local.enable_demo5 ? module.demo5[0].project_id : null
}

output "zone_demo5" {
    value = local.zone_demo5
}

output "zone_secondary_demo5" {
    value = local.zone_secondary_demo5
}
