variable "project" {
  type = string
  default = null
}

variable "name" {
  type = string
}

variable "network" {
}

variable "cidr_ranges" {
  type = list(string)
}
