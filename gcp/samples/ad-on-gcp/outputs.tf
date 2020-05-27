output "path-module" {
  value = path.module
}

output "path-meta" {
  value = module.sysprep.path-meta
}

output "path-specialize" {
  value = module.sysprep.path-specialize
}

output "network" {
  value = google_compute_network.network.self_link
}

output "subnets" {
  value = [google_compute_subnetwork.subnets[0].self_link, google_compute_subnetwork.subnets[1].self_link]
}
