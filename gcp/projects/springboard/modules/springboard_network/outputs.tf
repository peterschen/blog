output "id" {
  value = google_compute_network.network.id
  description = "Fully qualified resource ID"
}

output "name" {
  value = google_compute_network.network.name
  description = "Resource name"
}
