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
  default = "n2-standard-2"
}

variable "domain-name" {
  type = string
}

variable "password" {
  type = string
}

variable "windows_image" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "node-count" {
  type = number
  default = 2
}

variable "enable-cluster" {
  type = bool
  default = true
}

variable "enable-hdd" {
  type = bool
  default = false
}
