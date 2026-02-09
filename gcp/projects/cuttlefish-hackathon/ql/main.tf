resource "google_project_iam_member" "hackathon_controller" {
  project = var.gcp_project_id
  role = "roles/editor"
  member = "serviceAccount:hackathon-controller@axion-hackaton-3298.iam.gserviceaccount.com"
}
