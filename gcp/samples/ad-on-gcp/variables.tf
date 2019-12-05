variable "project" {
  default = "cbp-samples"
}

variable "region" {
  default = "europe-west3"
}

variable "zone" {
  default = "europe-west3-a"
}

variable "name-sample" {
  default = "ad-on-gce"
}

variable "name-domain" {
}

variable "password" {
  default = "Admin123Admin123"
}

variable "apis" {
  default = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com"]
}