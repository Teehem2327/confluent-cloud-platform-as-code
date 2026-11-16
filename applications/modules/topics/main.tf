terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.0"
    }
  }
}
resource "confluent_kafka_topic" "this" {
  for_each = var.topics
  kafka_cluster { id = var.kafka_cluster_id }
  topic_name       = each.value.name
  partitions_count = each.value.partitions
  config = {
    "retention.ms"   = each.value.retention_ms
    "cleanup.policy" = each.value.cleanup_policy
  }
  rest_endpoint = var.kafka_rest_endpoint
}
