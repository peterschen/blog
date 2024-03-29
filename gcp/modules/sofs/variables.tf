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
  default = "n2-standard-2"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "node_count" {
  type = number
  default = 2
}

variable "enable_cluster" {
  type = bool
  default = true
}

variable "enable_hdd" {
  type = bool
  default = false
}

variable "ssd_count" {
  type = number
  default = 4
}

variable "ssd_size" {
  type = number
  default = 100
}

variable "hdd_count" {
  type = number
  default = 4
}

variable "hdd_size" {
  type = number
  default = 100
}

