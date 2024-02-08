output "project_id" {
    description = "Project ID"
    value = module.project.id
}

output "region" {
    description = "Region"
    value = local.region
}

output "zone" {
    description = "Zone"
    value = local.zone
}

output "cluster" {
    description = "GKE cluster name"
    value = google_container_cluster.cluster.name
}
