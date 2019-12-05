variable "project" {
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
}

variable "uri-configurations" {
  default = "https://raw.githubusercontent.com/peterschen/blog/master/gcp/samples/ad-on-gcp/"
}
