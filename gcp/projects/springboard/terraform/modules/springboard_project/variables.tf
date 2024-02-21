variable "org_id" {
    type = number
    default = null
}

variable "folder_id" {
    type = number
    default = null
}

variable "billing_account" {
    type = string
    default = null
}

variable "apis" {
    type = list(string)
    default = []
}

variable "name" {
    type = string
    default = null
}

variable "suffix" {
    type = string
    default = null
}
