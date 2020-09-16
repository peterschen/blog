variable "project" {
}

variable "regions" {
  type = list(string)
  default = ["europe-west4", "europe-west1"]
}

variable "zones" {
  type = list(string)
  default = ["europe-west4-a", "europe-west1-b"]
}

variable "domain-name" {
  type = string
}

variable "password" {
  type = string
}

variable "count-nodes" {
  type = number
  default = 3
}

variable "enable-cluster" {
  type = bool
  default = true
}

variable "enable-hdd" {
  type = bool
  default = false
}
