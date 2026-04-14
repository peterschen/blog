variable "org_id" {
  description = "Organization ID in which the new project will be created"
  type = number
}

variable "billing_account" {
  description = "Billing Account which will be associated with the new project"
  type = string
}

variable "prefix" {
  description = "Prefix that will be prepended to the new project name"
  type = string
  default = null
}

variable "region" {
  description = "Name of the region"
  type = string
  default = "europe-west4"
}

variable "zone" {
  description = "Name of the zone"
  type = string
  default = "europe-west4-a"
}

variable "machine_type" {
  description = "Machine type for default node pool"
  type = string
  default = "e2-medium"
}

variable "password" {
  description = "Password to use for Cloud SQL instance"
  type = string
  sensitive = true
}
