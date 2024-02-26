terraform {
  required_version = ">= 1.2.3"

  required_providers {
    google = {
        source = "hashicorp/google"
        version = ">= 5.3"
    }
  }
  provider_meta "google" {
    module_name = "springboard/terraform/springboard_tier1/v1.0.0"
  }

  provider_meta "google-beta" {
    module_name = "springboard/terraform/springboard_tier1/v1.0.0"
  }
}