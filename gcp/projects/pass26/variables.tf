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

variable "project_id_demo" {
  type = string
  default = null
}

variable "project_id_demo4" {
  type = string
  default = null
}

variable "project_id_demo4_n2" {
  type = string
  default = null
}

variable "project_id_demo4_c3" {
  type = string
  default = null
}

variable "project_id_demo4_c4" {
  type = string
  default = null
}

variable "project_id_demo4_c4n" {
  type = string
  default = null
}

variable "region_demo" {
  type = string
  default = "europe-west4"
}

variable "region_demo4" {
  type = string
  default = "europe-west4"
}

variable "region_demo4_n2" {
  type = string
  default = "europe-west4"
}

variable "region_demo4_c3" {
  type = string
  default = "europe-west4"
}

variable "region_demo4_c4" {
  type = string
  default = "europe-west4"
}

variable "region_demo4_c4n" {
  type = string
  default = "europe-west4"
}

variable "zone_demo" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4_n2" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4_c3" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4_c4" {
  type = string
  default = "europe-west4-a"
}

variable "zone_demo4_c4n" {
  type = string
  default = "europe-west4-a"
}

variable "enable_demo4" {
  type = bool
  default = true
}

variable "enable_demo4_n2" {
  type = bool
  default = true
}

variable "enable_demo4_c3" {
  type = bool
  default = true
}

variable "enable_demo4_c4" {
  type = bool
  default = true
}

variable "enable_demo4_c4n" {
  type = bool
  default = true
}
