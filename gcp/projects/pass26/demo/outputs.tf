output "project_id" {
  value = data.google_project.project.project_id
}

output "zones" {
    value = local.zones
}

output "network_id" {
  value = google_compute_network.network.id
}

output "network_name" {
  value = google_compute_network.network.name
}

output "instances" {
  value = local.enable_sql ? one(module.sqlserver).instances : []
}
