variable "project_id" {
  type = string
  default = null
}

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

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022"
}

variable "windows_core_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "sql_image" {
  type = string
  default = "windows-cloud/windows-2022"
}

variable "enable_cluster" {
  type = bool
  default = false
}

variable "enable_alwayson" {
  type = bool
  default = false
}
