variable "regions" {
  type = list(string)
}

variable "zones" {
  type = list(string)
}

variable "network" {
  type = string
}

variable "subnetworks" {
  type = list(string)
}

variable "machine_type" {
  type = string
  default = "n1-standard-1"
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
}
