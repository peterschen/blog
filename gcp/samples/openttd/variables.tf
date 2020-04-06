variable "project" {
  type = string
}

variable "region" {
  type = string
  default = "europe-west1"
}

variable "zone" {
  type = string
  default = "europe-west1-b"
}

variable "serverPassword" {
  type = string
  default = ""
}

variable "adminPassword" {
  type = string
  default = ""
}

variable "rconPassword" {
  type = string
  default = ""
}

variable "generationSeed" {
  type = number
  default = 761267215162
}

variable "mapX" {
  type = number
  default = 9
}

variable "mapY" {
  type = number
  default = 9
}
