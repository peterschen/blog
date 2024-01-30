output "project_id" {
    description = "Project ID"
    value = module.project.id
}

output "project_number" {
    description = "Project number"
    value = module.project.number
}

output "zone" {
    description = "Zone"
    value = local.zone
}

output "tag_value_id_enabled" {
    description = "Tag Value ID (endabled)"
    value = google_tags_tag_value.enabled.id
}

output "tag_value_id_disabled" {
    description = "Tag Value ID (disabled)"
    value = google_tags_tag_value.disabled.id
}