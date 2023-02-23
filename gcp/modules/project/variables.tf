variable "org_id" {
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

variable "prefix" {
    type = string
    default = null
}
