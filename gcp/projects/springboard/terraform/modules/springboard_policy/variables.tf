variable "project_name" {
    type = string
    default = null
}

variable "constraints" {
    type = list(
        object({
            constraint = string
            type = string
            enforce = optional(bool)
            allowed_values = optional(list(string))
            denied_values = optional(list(string))
        })
    )
    default = []
}
