variable "region" {
    type = string
}

variable "zone" {
    type = string
}

variable "network" {
    type = string
}

variable "subnetwork" {
    type = string
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

# Enabled by default
variable "enable-hammerdb" {
    type = bool
    default = true
}

# Enabled by default
variable "enable-diskspd" {
    type = bool
    default = true
}

