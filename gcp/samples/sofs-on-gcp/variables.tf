variable "project" {
}

variable "region" {
  default = "europe-west1"
}

variable "zone" {
  default = "europe-west1-c"
}

variable "name-domain" {
}

variable "password" {
}

variable "uri-meta" {
  default = "https://raw.githubusercontent.com/peterschen/blog/master/gcp/samples/ad-on-gcp"
}

variable "uri-configurations" {
  default = "https://raw.githubusercontent.com/peterschen/blog/master/gcp/samples/sofs-on-gcp"
}
