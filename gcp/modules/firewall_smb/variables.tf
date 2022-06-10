variable "project" {
  type = string
  default = null
}

variable "name" {
  type = string
  default = "allow-smb"
}

variable "network" {
  type = string
  default = null
}

variable "cidr_ranges" {
  type = list(string)
}
