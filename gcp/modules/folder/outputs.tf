output "id" {
  value = replace(google_folder.folder.id, "folders/", "")
}

output "name" {
  value = google_folder.folder.name
}
