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

variable "region_scheduler" {
  type = string
  default = "europe-west3"
}

variable "prefix" {
  type = string
  default = null
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}

variable "retention" {
  type = number
  description = "Retention time of snapshots in seconds"
  default = 60 * 60 * 24 * 31
}