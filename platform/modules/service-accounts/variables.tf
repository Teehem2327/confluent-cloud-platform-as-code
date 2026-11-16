
variable "service_accounts" {
  description = "Map of Confluent Cloud service accounts."
  type = map(object({
    display_name = string
    description  = string
  }))

  default = {}
}
