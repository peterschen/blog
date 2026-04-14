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

output "cloudbuild_connection" {
    description = "Cloud Build v2 connection name"
    value = google_cloudbuildv2_connection.connection.name
}

output "cloudbuild_repository" {
    description = "Cloud Build v2 repository name"
    value = google_cloudbuildv2_repository.repository.name
}

output "cluster" {
    description = "GKE cluster name"
    value = google_container_cluster.cluster.name
}

# output "pool" {
#     description = "GKE node pool name"
#     value = google_container_node_pool.pool.name
# }

output "registry_name" {
    description = "Artifact Registry name"
    value = google_artifact_registry_repository.repository.name
}

