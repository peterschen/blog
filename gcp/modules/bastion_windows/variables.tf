variable "project" {
    type = string
    default = null
}

variable "project_network" {
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

variable "machine_type" {
    type = string
    default = "n4-standard-2"
}

variable "machine_name" {
    type = string
}

variable "password" {
    type = string
    sensitive = true
}

variable "domain_name" {
    type = string
    default = null
}

variable "windows_image" {
    type = string 
    default = "windows-cloud/windows-2022"
}

variable "enable_domain" {
    type = bool
    default = false
}

variable "enable_ssms" {
    type = bool
    default = false
}

# Enabled by default
variable "enable_hammerdb" {
    type = bool
    default = true
}

# Enabled by default
variable "enable_diskspd" {
    type = bool
    default = true
}

# Enabled by default
variable "enable_python" {
    type = bool
    default = true
}

# Disabled by default
variable "enable_discoveryclient" {
    type = bool
    default = false
}

# Disabled by default
variable "enable_windowsadmincenter" {
    type = bool
    default = false
}

variable "configuration_customization" {
  type = string
  default = null
}
