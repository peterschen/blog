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

variable "machineType" {
  type = string
  default = "n2-standard-2"
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "nameDomain" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}