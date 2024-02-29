output "region" {
  value = var.region
}

output "zone" {
  value = var.zone
}

output "project_id" {
  value = module.project.id
  description = "Project ID"
}

output "bucket_name" {
  value = google_storage_bucket.bucket.name
  description = "Bucket name"
}
