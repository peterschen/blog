variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "project_id" {
  type = string
  default = null
}

variable "prefix" {
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

variable "machine_type" {
  type = string
  default = "c4-standard-16"
}

variable "domain_name" {
  type = string
  default = "smtoff.lab"
}

variable "password" {
  sensitive = true
}
