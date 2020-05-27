variable "project" {
}

variable "regions" {
  type = list(string)
}

variable "zones" {
  type = list(string)
}

variable "network" {
}

variable "subnetworks" {
}

variable "name-domain" {
  type = string
}

variable "password" {
  type = string
}
