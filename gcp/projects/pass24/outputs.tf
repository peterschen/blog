output "project_id_demo5" {
  value = local.enable_demo5 ? module.demo5[0].project_id : null
}

output "zone_demo5" {
    value = local.zone_demo5
}

output "zone_secondary_demo5" {
    value = local.zone_secondary_demo5
}

output "links_demo5" {
  value = local.enable_demo5 ? [
    "https://console.cloud.google.com/compute/disks?project=${module.demo5[0].project_id}",
    "https://console.cloud.google.com/compute/asynchronousReplication?project=${module.demo5[0].project_id}&tab=async_replication_disks",
    "https://console.cloud.google.com/compute/asynchronousReplication?project=${module.demo5[0].project_id}&tab=consistency_groups"
  ] : null
}

output "links_demo6" {
  value = local.enable_demo6 ? [
    "https://console.cloud.google.com/compute/disks?project=${module.demo6[0].project_id}",
    "https://console.cloud.google.com/monitoring/dashboards/builder/${google_monitoring_dashboard.demo6_dashboard[0].id};duration=PT30M?project=${module.demo6[0].project_id}"
  ] : null
}

output "rdp_demo5" {
  value = local.enable_demo5 ? [
    "rdp bastion --project ${module.demo5[0].project_id} --zone ${local.zone_demo5} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-0 --project ${module.demo5[0].project_id} --zone ${local.zone_demo5} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ] : null
}

output "rdp_demo6" {
  value = local.enable_demo6 ? [
    "rdp bastion --project ${module.demo6[0].project_id} --zone ${local.zone_demo6} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-0 --project ${module.demo6[0].project_id} --zone ${local.zone_demo6} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ] : null
}