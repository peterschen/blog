variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "project_name" {
  type = string
  default = null
}

variable "project_prefix" {
  type = string
  default = null
}

variable "project_suffix" {
  type = string
  default = null
}

variable "subnets" {
    type = list(
        object({
            region = string,
            name = string,
            range = string,
            private_ipv4_google_access = bool,
            private_ipv6_google_access = bool
        })
    )
}

variable "peer_networks" {
    type = list(string)
    default = []
}

variable "enable_peering" {
    type = bool
    default = false
}
