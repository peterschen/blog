variable "project_name" {
    type = string
    default = null
}

variable "network_name" {
    type = string
    default = null
}

variable "rules" {
  type = list(
    object({
      name = string,
      priority = number,
      disabled = bool
      allow = list(
        object({
          protocol = string,
          ports = list(string)
        })
      ),
      deny = list(
        object({
          protocol = string,
          ports = list(string)
        })
      ),
      source_tags = list(string),
      target_tags = list(string),
      source_ranges = list(string),
      destination_ranges = list(string),
      logging = bool
    })
  )
  default = []
}
