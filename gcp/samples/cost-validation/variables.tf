variable "org_id" {
  type = number
}

variable "billing_account" {
  type = string
}

variable "region" {
  type = string
  default = "europe-west4"
}

variable "zone" {
  type = string
  default = "europe-west4-a"
}

variable "scenarios" {
  type = list(
    object(
      {
        name: string
        shape: string
      }
    )
  )
  default = [
    {
      name = "e2-standard"
      shape = "e2-standard-2"
    },
    {
      name = "e2-custom"
      shape = "e2-custom-2-8192"
    }
  ]
}
