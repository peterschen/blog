variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "region" {
  type = string
  default = "europe-west4"
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}

variable "prefix" {
  type = string
  default = null
}

variable "machine_type" {
  type = string
  default = "e2-standard-2"
}
