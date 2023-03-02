variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "region_onprem" {
  type = string
  default = "europe-west4"
}

variable "region_cloud" {
  type = string
  default = "europe-west1"
}

variable "region_vpn" {
  type = string
  default = "europe-west3"
}

variable "zone_onprem" {
  type = string
  default = "europe-west4-a"
}

variable "zone_cloud" {
  type = string
  default = "europe-west1-b"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}
