variable "project" {
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

variable "region-scheduler" {
  type = string
  default = "europe-west1"
}

variable "domain-name" {
}

variable "password" {
}

variable "cloudIdentityDomain" {
  type = string
  default = null
}

variable "enableCertificateAuthority" {
  type = bool
  default = false
}

variable "enableAdfs" {
  type = bool
  default = false
}

# This adds a Serverless VPC access in europe-west1 while
# Directory Sync is in preview and only supports west1
variable "enableDirectorySync" {
  type = bool
  default = false
}