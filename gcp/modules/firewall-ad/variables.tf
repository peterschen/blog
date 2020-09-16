variable "name" {
  type = string
}

variable "network" {
  type = string
}

variable "cidr-ranges" {
  type = list(string)
}
