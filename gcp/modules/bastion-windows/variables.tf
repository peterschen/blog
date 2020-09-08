variable "project" {
    type = string
}

variable "zone" {
    type = string
}

variable "network" {
}

variable "subnetwork" {
}

variable "machine-type" {
    type = string
    default = "n1-standard-2"
}

variable "machine-name" {
    type = string
}

variable "password" {
    type = string
}

variable "domain-name" {
    type = string
    default = ""
}

variable "enable-domain" {
    type = bool
    default = false
}

variable "enable-ssms" {
    type = bool
    default = false
}

variable "enable-hammerdb" {
    type = bool
    default = false
}
