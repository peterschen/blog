variable "project" {
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "machine-type" {
    type = string
    default = "n2-standard-4"
}

variable "domain-name" {
  type = string
}

variable "password" {
  type = string
}
