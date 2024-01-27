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

variable "prefix" {
  type = string
  default = null
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}