output "id" {
  value = google_project.project.project_id

  depends_on = [
    google_project_service.apis
  ]
}

output "name" {
  value = google_project.project.name

  depends_on = [
    google_project_service.apis
  ]
}

output "number" {
  value = google_project.project.number

  depends_on = [
    google_project_service.apis
  ]
}