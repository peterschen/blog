variable "project" {
  default = "cbp-playground"
}

variable "region_remote" {
  default = "europe-west3"
}

variable "region_local" {
  default = "europe-west4"
}

variable "zone_remote" {
  default = "europe-west3-a"
}

variable "zone_local" {
  default = "europe-west4-a"
}

variable "name_sample" {
  default = "hybrid-connectivity"
}

variable "name_networks" {
    default = ["remote", "local"]
}