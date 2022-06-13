variable "project" {
  type = string
  default = null
}

variable "project_network" {
  type = string
  default = null
}

variable "regions" {
  type = list(string)
}

variable "zones" {
  type = list(string)
}

variable "network" {
  type = string
}

variable "subnetworks" {
  type = list(string)
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "machine_type" {
  type = string
  default = "e2-medium"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "enable_ssl" {
  type = bool
  default = false
}