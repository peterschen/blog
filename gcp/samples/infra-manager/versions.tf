terraform {
  required_version = "< 1.2.3"

  required_providers {
    google = {
        source = "hashicorp/google"
        version = ">= 5.3"
    }
  }
}