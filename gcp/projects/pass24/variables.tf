variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "domain_name" {
}

variable "password" {
  sensitive = true
}

variable "project_id_demo5" {
  type = string
  default = null
}

variable "project_id_demo6" {
  type = string
  default = null
}

variable "region_demo5" {
  type = string
  default = "europe-west4"
}

variable "region_demo6" {
  type = string
  default = "europe-west4"
}

variable "region_secondary_demo5" {
  type = string
  default = "europe-west3"
}

variable "zone_demo5" {
  type = string
  default = "europe-west4-a"
}

variable "zone_secondary_demo5" {
  type = string
  default = "europe-west3-c"
}

variable "zone_demo6" {
  type = string
  default = "europe-west4-a"
}

variable "enable_demo5" {
  type = bool
  default = true
}

variable "enable_demo6" {
  type = bool
  default = true
}
