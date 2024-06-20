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

variable "zones" {
  type = list(string)
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "windows_image" {
  type = string
  default = "windows-sql-cloud/sql-ent-2022-win-2022"
}

variable "machine_type" {
  type = string
  default = "n4-standard-4"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "enable_cluster" {
  type = bool
  default = false
}

variable "enable_alwayson" {
  type = bool
  default = false
}
