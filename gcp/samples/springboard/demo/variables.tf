variable "org_id" {
    type = number
    default = null
}

variable "billing_account" {
    type = string
    default = null
}

variable "project_name" {
  type = string
  default = null
}

variable "project_suffix" {
  type = string
  default = null
}

variable "allowed_regions" {
    type = list(string)
    default = []
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
