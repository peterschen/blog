variable "project" {
  type = string
  default = null
}

variable "project_network" {
  type = string
  default = null
}

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
  default = "n2-standard-4"
}

variable "windows_image" {
  type = string
  default = "windows-sql-cloud/sql-ent-2019-win-2022"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "enable_aag" {
  type = bool
  default = false
}
