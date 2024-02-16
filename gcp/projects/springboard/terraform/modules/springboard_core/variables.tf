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

variable "project_name" {
  type = string
  default = null
}

variable "allowed_apis" {
    type = list(string)
    default = []
}

variable "allowed_regions" {
    type = list(string)
    default = []
}

variable "constraints" {
    type = list(
        object({
            constraint = string
            type = string
            enforce = bool
            allowed_values = list(string)
            denied_values = list(string)
        })
    )
    default = []
}
