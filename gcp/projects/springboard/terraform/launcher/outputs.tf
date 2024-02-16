output "project_id" {
  value = module.project.id
  description = "Project ID"
}

output "sa_id" {
  value = google_service_account.service_account.id
  description = "ID for service account"
}
