variable "project" {
}

variable "region" {
  type = string
  default = "europe-west4"
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}

variable "machine-type" {
  type = string
  default = "n2-standard-2"
}

variable "password" {
}

variable "node-count" {
  type = number
  default = 1
}
