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
    "europe-west4-b",
  ]
}

variable "domain_name" {
  type = string
  default = "sqlag.lab"
}

variable "password" {
  sensitive = true
}

variable "machine_type_dc" {
  type = string
  default = "n4-highcpu-2"
}

variable "machine_type_bastion" {
  type = string
  default = "n4-highcpu-4"
}

variable "machine_type_sql" {
  type = string
  default = "n4-highcpu-4"
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

variable "use_developer_edition" {
  type = bool
  default = true
}

variable "enable_cluster" {
  type = bool
  default = true
}