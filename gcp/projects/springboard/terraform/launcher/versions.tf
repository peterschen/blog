terraform {
  required_version = ">= 1.6.2"

  required_providers {
    google = {
        source = "hashicorp/google"
        version = ">= 5.16"
    }

    google-beta = {
        source = "hashicorp/google-beta"
        version = ">= 5.16"
    }
  }
}