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

variable "project_id_demo1" {
  type = string
  default = null
}

variable "project_id_demo3" {
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

variable "region_demo3" {
  type = string
  default = "europe-west4"
}

variable "region_demo4" {
  type = string
  default = "europe-west4"
}

variable "region_secondary_demo3" {
  type = string
  default = "europe-west3"
}

variable "zone_demo1" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo3" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4" {
  type = string
  default = "europe-west4-a"
}

variable "zone_secondary_demo3" {
  type = string
  default = "europe-west3-c"
}

variable "enable_demo1" {
  type = bool
  default = true
}

variable "enable_demo3" {
  type = bool
  default = true
}

variable "enable_demo4" {
  type = bool
  default = true
}
