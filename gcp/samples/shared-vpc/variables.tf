variable "region" {
  type = string
  default = "europe-west4"
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}

variable "hostProjectName" {
  type = string
}

variable "serviceProjectName" {
  type = string
}

variable "password" {
  type = string
  sensitive = true
}
