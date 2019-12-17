variable "project" {
}

variable "regions" {
  type = "list"
}

variable "zones" {
  type = "list"
}

variable "name-domain" {
}

variable "password" {
}

variable "uri-meta" {
  default = "https://raw.githubusercontent.com/peterschen/blog/master/gcp/samples/ad-on-gcp"
}

variable "uri-configurations" {
  default = "https://raw.githubusercontent.com/peterschen/blog/master/gcp/samples/ad-on-gcp"
}
