variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "name" {
  type = string
  default = null
}

variable "prefix" {
  type = string
  default = null
}

variable "peer_networks" {
    type = list(string)
    default = []
}

variable "shared_networks" {
    type = list(string)
    default = []
}
