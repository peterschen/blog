output "path-module" {
  value = path.module
}

output "path-specialize" {
  value = module.ad-on-gcp.path-specialize
}

output "network" {
  value = module.ad-on-gcp.network
}

output "subnets" {
  value = module.ad-on-gcp.subnets
}
