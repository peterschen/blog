variable "project" {
  type = string
  default = null
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
  default = "auto-ad-join"
}

variable "machineType"  {
  type = string
  default = "n2-standard-4"
}

variable "domainName" {
  type = string
  default = null
}

variable "password" {
  type = string
  default = null
  sensitive = true
}
