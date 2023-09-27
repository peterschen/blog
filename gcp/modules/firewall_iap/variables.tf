variable "project" {
    type = string
    default = null
}

variable "network" {
}

variable "enable_rdp" {
    type = bool
    default = true
}

variable "enable_ssh" {
    type = bool
    default = true
}

variable "enable_http" {
    type = bool
    default = false
}

variable "enable_http_alt" {
    type = bool
    default = false
}

variable "enable_https" {
    type = bool
    default = false
}

variable "enable_https_alt" {
    type = bool
    default = false
}