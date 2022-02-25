variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "machine_type" {
  type = string
  default = "n2-standard-2"
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "domain_name" {
  type = string
}

variable "cloud_identity_domain" {
  type = string
  default = null
}

variable "password" {
  type = string
  sensitive = true
}