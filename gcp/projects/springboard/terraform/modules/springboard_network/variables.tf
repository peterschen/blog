variable "project_name" {
    type = string
    default = null
}

variable "name" {
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
