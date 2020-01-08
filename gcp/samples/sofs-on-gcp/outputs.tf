output "path-module" {
  value = path.module
}

output "network" {
  value = module.ad-on-gcp.network
}

output "subnets" {
  value = module.ad-on-gcp.subnets
}
