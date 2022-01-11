variable "project" {
  type = string
  default = null
}

variable "namePrefix" {
  type = string
}

variable "network" {
  type = string
}

variable "cidrRanges" {
  type = list(string)
}
