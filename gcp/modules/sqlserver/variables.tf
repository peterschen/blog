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
  default = "windows-cloud/windows-2022"
}

variable "machine_type" {
  type = string
  default = "n4-standard-4"
}

variable "machine_prefix" {
  type = string
  default = "sql"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "use_developer_edition" {
  type = bool
  default = true
}

variable "enable_firewall" {
  type = bool
  default = true
}

variable "enable_cluster" {
  type = bool
  default = false
}

variable "configuration_customization" {
  type = list(string)
  default = []
}