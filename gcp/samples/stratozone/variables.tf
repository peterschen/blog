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

variable "networkRange" {
  type = string
  default = "10.0.0.0/16"
}

variable "machineType"  {
  type = string
  default = "n2-standard-4"
}

variable "enableDomain" {
  type = bool
  default = true
}

variable "domainName" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}
