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

variable "nameDomain" {
  type = string
}

variable "cloudIdentityDomain" {
  type = string
  default = null
}

variable "password" {
  type = string
  sensitive = true
}