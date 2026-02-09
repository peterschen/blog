resource "google_project_iam_member" "hackathon_controller" {
  project = var.gcp_project_id
  role = "roles/editor"
  member = "serviceAccount:hackathon-controller@axion-hackaton-3298.iam.gserviceaccount.com"
}

module "cli" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 4.0.0"
  platform = "linux"

  additional_components = []
  create_cmd_entrypoint = "chmod +x ${path.module}/script.sh;${path.module}/script.sh"
  create_cmd_body = "${var.gcp_project_id} ${var.base_uri}"
  skip_download = false
  upgrade = false
  gcloud_sdk_version = "555.0.0"
  service_account_key_file = var.service_account_key_file
}
