variable "project" {
  type = string
  default = null
}

variable "name" {
  type = string
}

variable "network" {
  type = string
}

variable "cidr-ranges" {
  type = list(string)
}
