variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "prefix" {
  type = string
  default = null
}

variable "regions" {
  type = list(string)
  default = [
    "europe-west4",
    "europe-west1"
  ]
}

variable "zones" {
  type = list(string)
  default = [
    "europe-west4-a",
    "europe-west1-b"
  ]
}

variable "region_scheduler" {
  type = string
  default = "europe-west1"
}

variable "domain_name" {
}

variable "password" {
  sensitive = true
}

variable "machine_type_dc" {
  type = string
  default = "n4-highcpu-2"
}

variable "machine_type_ca" {
  type = string
  default = "n4-highcpu-2"
}

variable "machine_type_bastion" {
  type = string
  default = "n4-highcpu-4"
}

variable "machine_type_adjoin" {
  type = string
  default = "n4-highcpu-2"
}

variable "machine_type_joinvm" {
  type = string
  default = "e2-medium"
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022"
}

variable "windows_core_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "adjoin_container_uri" {
  type = string
  default = "europe-west4-docker.pkg.dev/cbpetersen-shared/gce-automated-ad-join/register-computer:latest"
}

variable "cloud_identity_domain" {
  type = string
  default = null
}

variable "enable_adjoin" {
  type = bool
  default = true
}

variable "enable_adcs" {
  type = bool
  default = false
}

variable "enable_adfs" {
  type = bool
  default = false
}

# This adds a Serverless VPC access in europe-west1 while
# Directory Sync is in preview and only supports west1
variable "enable_directorysync" {
  type = bool
  default = false
}

# Migration Center Discovery Client installation on bastion
variable "enable_discoveryclient" {
  type = bool
  default = true
}
