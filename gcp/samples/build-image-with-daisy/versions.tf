terraform {
  required_version = ">= 1.7.2"

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