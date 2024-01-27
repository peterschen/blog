output "project_id" {
    description = "Project ID"
    value = module.project.id
}

output "zone" {
    description = "Zone"
    value = local.zone
}

output "tag_key_id" {
    description = "Tag Key ID"
    value = google_tags_tag_key.protection.id
}

output "tag_value_id" {
    description = "Tag Value ID"
    value = google_tags_tag_value.enabled.id
}
