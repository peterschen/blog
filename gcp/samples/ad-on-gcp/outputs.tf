output "path-module" {
  value = path.module
}

output "network" {
  value = google_compute_network.network.self_link
}

output "subnet" {
  value = google_compute_subnetwork.network-subnet.self_link
}
