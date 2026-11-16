
variable "role_bindings" {
  description = "Map of Confluent Cloud RBAC assignments."

  type = map(object({
    principal   = string
    role_name   = string
    crn_pattern = string
  }))

  default = {}
}
