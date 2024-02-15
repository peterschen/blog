output "project_workload_id" {
    description = "Project ID"
    value = module.project_workload.id
}

output "zone" {
    description = "Zone"
    value = local.zone
}

output "tag_value_id" {
    description = "Tag Value ID"
    value = google_tags_tag_value.true.id
}