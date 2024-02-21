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

variable "peer_networks" {
  type = list(string)
  default = []
}

variable "shared_networks" {
  type = list(string)
  default = []
}

variable "firewall_rules" {
    type = list(
        object({
            name = string,
            priority = number,
            direction = string,
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
