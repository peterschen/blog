variable "project" {
    type = string
    default = null
}

variable "apis" {
    type = list(string)
    default = ["cloudresourcemanager.googleapis.com", "compute.googleapis.com"]
}
