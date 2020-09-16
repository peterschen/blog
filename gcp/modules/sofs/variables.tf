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
  default = "n2-standard-2"
}

variable "domain-name" {
  type = string
}

variable "password" {
  type = string
}

variable "node-count" {
  type = number
  default = 2
}

variable "enable-cluster" {
  type = bool
  default = true
}

variable "enable-hdd" {
  type = bool
  default = false
}
