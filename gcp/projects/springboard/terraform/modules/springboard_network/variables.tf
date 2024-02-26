variable "project_name" {
    type = string
    default = null
}

variable "name" {
    type = string
    default = null
}

variable "subnets" {
    type = list(
        object({
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

variable "shared_networks" {
    type = list(string)
    default = []
}
