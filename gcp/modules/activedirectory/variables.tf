variable "project" {
}

variable "regions" {
  type = list(string)
  default = ["europe-west1", "europe-west4"]
}

variable "zones" {
  type = list(string)
  default = [
    "europe-west1-b",
    "europe-west4-a"
  ]
}

variable "network" {
}

variable "subnetworks" {
}

variable "name-domain" {
  type = string
}

variable "password" {
  type = string
}
