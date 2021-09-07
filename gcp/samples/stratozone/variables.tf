variable "project" {
}

variable "region" {
  type = string
  default = "europe-west4"
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}

variable "networkName" {
  type = string
  default = "stratozone"
}

variable "machineType"  {
  type = string
  default = "n2-standard-4"
}

variable "domainName" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "enableDomain" {
  type = bool
  default = true
}

variable "enableStratozone" {
  type = bool
  default = true
}
