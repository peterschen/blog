variable "project" {
    type = string
    default = null
}

variable "projectNetwork" {
    type = string
    default = null
}

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
    default = null
}

variable "windows_image" {
    type = string 
    default = "windows-cloud/windows-2022"
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

# Enabled by default
variable "enablePython" {
    type = bool
    default = true
}
