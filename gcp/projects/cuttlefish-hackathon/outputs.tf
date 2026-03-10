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

output "bucket" {
    value = google_storage_bucket.bucket.name
}

output "service_account" {
    value = google_service_account.hackathon_controller.email
}
