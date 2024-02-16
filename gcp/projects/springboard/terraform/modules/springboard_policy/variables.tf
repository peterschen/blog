variable "project_name" {
    type = string
    default = null
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
