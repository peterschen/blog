output "id" {
  value = google_compute_network.network.id
  description = "Fully qualified resource ID"
}

output "name" {
  value = google_compute_network.network.name
  description = "Resource name"
}

output "subnet_ids" {
  value = google_compute_subnetwork.subnet[*].id
  description = "Fully qualified resource IDs of subnetworks"
}

output "subnet_names" {
  value = google_compute_subnetwork.subnet[*].name
  description = "Rsource name of subnetworks"
}
