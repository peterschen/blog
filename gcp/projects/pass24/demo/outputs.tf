output "project_id" {
  value = data.google_project.project.project_id
}

output "zones" {
    value = local.zones
}

output "instances" {
    value = module.sqlserver.instances
}
