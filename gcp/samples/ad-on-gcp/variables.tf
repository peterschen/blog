variable "project" {
}

variable "regions" {
  type = list(string)
  default = ["europe-west1", "europe-west4"]
}

variable "zones" {
  type = list(list(string))
  default = [
    ["b"],
    ["a"]
  ]
}

variable "name-domain" {
}

variable "password" {
}

variable "uri-meta" {
  default = "https://raw.githubusercontent.com/peterschen/blog/master/gcp/samples/ad-on-gcp"
}
