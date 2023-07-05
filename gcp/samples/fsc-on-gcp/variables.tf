variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "ad_zones" {
  type = list(string)
  default = [
    "europe-west4-a",
    "europe-west1-b"
  ]
}

variable "cluster_zones" {
  type = list(string)
  default = [
    "europe-west4-a",
    "europe-west4-a"
  ]
}

variable "witness_zone" {
  type = string
  default = "europe-west4-c"
}

variable "bastion_zone" {
  type = string
  default = "europe-west4-c"
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

variable "windows_image_dc" {
  type = string
  default = "windows-cloud/windows-2022-core"
}

variable "windows_image_bastion" {
  type = string
  default = "windows-cloud/windows-2022"
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
  default = true
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
