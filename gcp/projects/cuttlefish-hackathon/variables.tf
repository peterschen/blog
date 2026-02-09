variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "project_id" {
  type = string
  default = null
}

variable "region" {
  type = string
  default = "us-central1"
}

variable "zone" {
  type = string
  default = "us-central1-a"
}
