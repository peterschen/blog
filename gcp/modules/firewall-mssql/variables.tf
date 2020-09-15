variable "name" {
  type = string
}

variable "network" {
}

variable "cidr-ranges" {
  type = list(string)
}
