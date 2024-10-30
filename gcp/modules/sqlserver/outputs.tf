output "instances" {
  value = google_compute_instance.sql
}

output "wsfc_address" {
  value = local.enable_cluster ? google_compute_address.wsfc[0].address : null 
}

output "wsfc_sql_address" {
  value = local.enable_cluster ? google_compute_address.wsfc_sql[0].address : null 
}
