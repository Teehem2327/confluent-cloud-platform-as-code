output "environment_id" {
  description = "Confluent Cloud test environment ID"
  value       = confluent_environment.test.id
}
# Phase 8: selected non-sensitive identifiers for downstream configuration.
# Empty strings mean the optional resources have not been provisioned.
output "kafka_cluster_id" {
  description = "TEST Kafka cluster ID; empty while cluster deployment is disabled."
  value       = length(module.kafka_cluster) > 0 ? module.kafka_cluster[0].cluster_id : ""
}

output "kafka_rest_endpoint" {
  description = "TEST Kafka REST endpoint; empty while cluster deployment is disabled."
  value       = length(module.kafka_cluster) > 0 ? module.kafka_cluster[0].rest_endpoint : ""
}

output "application_service_account_id" {
  description = "Application service account ID; empty while service accounts are disabled."
  value       = lookup(module.service_accounts.service_account_ids, "application", "")
}
