variable "acls" {
  description = "ACLs indexed by logical name."
  type = map(object({
    resource_type = string
    resource_name = string
    pattern_type  = string
    principal     = string
    host          = string
    operation     = string
    permission    = string
  }))
  default = {}
}
variable "kafka_cluster_id" { type = string }
variable "kafka_rest_endpoint" { type = string }
