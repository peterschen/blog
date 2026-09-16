variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "domain_name" {
  type = string
  default = "pass.lab"
}

variable "password" {
  sensitive = true
}

variable "project_id_demo1" {
  type = string
  default = null
}

variable "project_id_demo4" {
  type = string
  default = null
}

variable "region_demo1" {
  type = string
  default = "europe-west4"
}

variable "region_demo4" {
  type = string
  default = "europe-west4"
}

variable "zone_demo1" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4" {
  type = string
  default = "europe-west4-a"
}

variable "enable_demo1" {
  type = bool
  default = true
}

variable "enable_demo4" {
  type = bool
  default = true
}
