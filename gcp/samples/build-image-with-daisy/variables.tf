variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "project_prefix" {
  type = string
  default = null
}

variable "region" {
  type = string
  default = "europe-west4"
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}
