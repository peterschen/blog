output "project_id_demo1" {
  value = local.enable_demo1 ? module.demo1[0].project_id : null
}

output "project_id_demo3" {
  value = local.enable_demo3 ? module.demo3[0].project_id : null
}

output "zone_demo1" {
    value = local.enable_demo1 ? local.zone_demo1 : null
}

output "zone_demo3" {
    value = local.enable_demo3 ? local.zone_demo3 : null
}

output "zone_secondary_demo3" {
    value = local.enable_demo3 ? local.zone_secondary_demo3 : null
}

output "links_demo1" {
  value = local.enable_demo1 ? [
    "https://console.cloud.google.com/compute/instancesAdd?project=${module.demo1[0].project_id}&googleTemplateId=sql-server&initialName=pass-demo-1&instanceZone=europe-west4-a",
    "https://console.cloud.google.com/monitoring/dashboards/resourceList/gce_instance;duration=PT30M?project=${module.demo1[0].project_id}",
    "https://console.cloud.google.com/monitoring/dashboards/integration/mssql.sqlserver-gce-overview;duration=PT30M?project=${module.demo1[0].project_id}",
    "https://console.cloud.google.com/monitoring/dashboards/integration/mssql.sqlserver-transaction-logs;duration=PT30M?project=${module.demo1[0].project_id}",
    "https://console.cloud.google.com/monitoring/integrations?project=${module.demo1[0].project_id}&pageState=(%22integrations%22:(%22p%22:5),%22integrationsTable%22:(%22f%22:%22%255B%257B_22k_22_3A_22_22_2C_22t_22_3A10_2C_22v_22_3A_22_5C_22Microsoft%2520SQL%2520Server_5C_22_22_2C_22s_22_3Atrue%257D%255D%22))",
    "https://console.cloud.google.com/compute/disks?project=${module.demo1[0].project_id}",
  ] : null
}

output "links_demo2" {
  value = local.enable_demo2 ? [
    "https://console.cloud.google.com/compute/disks?project=${module.demo2[0].project_id}",
  ] : null
}

output "links_demo3" {
  value = local.enable_demo3 ? [
    "https://console.cloud.google.com/compute/disks?project=${module.demo3[0].project_id}",
    "https://console.cloud.google.com/compute/asynchronousReplication?project=${module.demo3[0].project_id}&tab=async_replication_disks",
    "https://console.cloud.google.com/compute/asynchronousReplication?project=${module.demo3[0].project_id}&tab=consistency_groups",
    "https://console.cloud.google.com/monitoring/dashboards/builder/${google_monitoring_dashboard.demo3_dashboard[0].id};duration=PT30M?project=${module.demo3[0].project_id}"
  ] : null
}

output "links_demo4" {
  value = local.enable_demo4 ? [
    "https://console.cloud.google.com/compute/disks?project=${module.demo4[0].project_id}",
    "https://console.cloud.google.com/monitoring/dashboards/builder/${google_monitoring_dashboard.demo4_dashboard[0].id};duration=PT30M?project=${module.demo4[0].project_id}"
  ] : null
}

output "rdp_demo" {
  value = [
    "rdp bastion --project ${data.google_project.project.project_id} --zone ${local.zone_demo} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ]
}

output "rdp_demo1" {
  value = local.enable_demo1 ? [
    "rdp bastion --project ${module.demo1[0].project_id} --zone ${local.zone_demo1} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-0 --project ${module.demo1[0].project_id} --zone ${local.zone_demo1} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ] : null
}

output "rdp_demo2" {
  value = local.enable_demo2 ? [
    "rdp bastion --project ${module.demo2[0].project_id} --zone ${local.zone_demo2} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-0 --project ${module.demo2[0].project_id} --zone ${local.zone_demo2} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-1 --project ${module.demo2[0].project_id} --zone ${local.zone_secondary_demo2} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ] : null
}

output "rdp_demo3" {
  value = local.enable_demo3 ? [
    "rdp bastion --project ${module.demo3[0].project_id} --zone ${local.zone_demo3} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-0 --project ${module.demo3[0].project_id} --zone ${local.zone_demo3} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-clone-0 --project ${module.demo3[0].project_id} --zone ${local.zone_secondary_demo3} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ] : null
}

output "rdp_demo4" {
  value = local.enable_demo4 ? [
    "rdp bastion --project ${module.demo4[0].project_id} --zone ${local.zone_demo4} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
    "rdp sql-0 --project ${module.demo4[0].project_id} --zone ${local.zone_demo4} -- /d:${local.domain_name} /u:Administrator /p:$TF_VAR_password /cert:ignore",
  ] : null
}
