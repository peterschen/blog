output "project" {
    value = data.google_project.project.project_id
}

output "region" {
    value = local.region
}

output "zone" {
    value = local.zone
}

output "database" {
    value = google_firestore_database.database.name
}
