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

variable "cluster_zones" {
  type = list(string)
}

variable "witness_zone" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}

variable "node_count" {
  type = number
  default = 2
}

variable "cluster_machine_type" {
  type = string
  default = "n2-highcpu-8"
}

variable "witness_machine_type" {
  type = string
  default = "e2-medium"
}

variable "windows_image_witness" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "windows_image_cluster" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "enable_cluster" {
  type = bool
  default = true
}

variable "enable_distributednodename" {
  type = bool
  default = false
}

variable "enable_storagespaces" {
  type = bool
  default = true
}

variable "cache_disk_count" {
  type = number
  default = 2
}

variable "cache_disk_interface" {
  type = string
  default = "SCSI"
}

variable "capacity_disk_count" {
  type = number
  default = 4
}

variable "capacity_disk_type" {
  type = string
  default = "pd-ssd"
}

variable "capacity_disk_size" {
  type = number
  default = "1024"
}