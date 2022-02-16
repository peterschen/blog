variable "project" {
}

variable "regions" {
  type = list(string)
  default = [
    "europe-west4",
    "europe-west1"
  ]
}

variable "zones" {
  type = list(string)
  default = [
    "europe-west4-a",
    "europe-west1-b"
  ]
}

variable "region-scheduler" {
  type = string
  default = "europe-west1"
}

variable "domain-name" {
}

variable "password" {
}

variable "cloudIdentityDomain" {
  type = string
  default = null
}

variable "enableCertificateAuthority" {
  type = bool
  default = false
}

variable "enableAdfs" {
  type = bool
  default = false
}
