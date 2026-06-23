variable "project_id" {
  type = string
  default = null
}

variable "org_id" {
  type = number
  default = null
}

variable "billing_account" {
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

variable "zones" {
  type = list(string)
  default = [
    "europe-west4-a",
    "europe-west4-b"
  ]
}

variable "domain_name" {
}

variable "password" {
  sensitive = true
}

variable "machine_type_bastion" {
  type = string
  default = "n4-highcpu-4"
}

variable "machine_type_sql" {
  type = string
  default = "n4-standard-4"
}

variable "visible_cores_sql" {
  type = number
  default = null
}

variable "threads_per_core_sql" {
  type = number
  default = null
}

variable "turbo_mode_sql" {
  type = bool
  default = null
}
