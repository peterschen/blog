variable "project" {
    type = string
}

variable "region" {
    type = string
}

variable "network" {
}

variable "enable-rdp" {
    type = bool
    default = true
}

variable "enable-ssh" {
    type = bool
    default = true
}
