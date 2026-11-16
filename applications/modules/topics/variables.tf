variable "topics" {
  description = "Topics indexed by logical name."
  type = map(object({
    name           = string
    partitions     = number
    retention_ms   = string
    cleanup_policy = string
  }))
  default = {}
  validation {
    condition = alltrue([
      for t in values(var.topics) :
      t.partitions >= 1 && floor(t.partitions) == t.partitions && contains(["delete", "compact"], t.cleanup_policy)
    ])
    error_message = "Partitions must be positive integers; cleanup policy must be delete or compact."
  }
}
variable "kafka_cluster_id" { type = string }
variable "kafka_rest_endpoint" { type = string }
