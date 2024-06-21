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
  default = "n4-standard-2"
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}