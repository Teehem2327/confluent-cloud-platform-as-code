
output "cluster_id" {
  description = "ID of the Confluent Cloud Kafka cluster."
  value       = confluent_kafka_cluster.this.id
}

output "cluster_name" {
  description = "Display name of the Kafka cluster."
  value       = confluent_kafka_cluster.this.display_name
}

output "bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint for clients."
  value       = confluent_kafka_cluster.this.bootstrap_endpoint
}

output "rest_endpoint" {
  description = "Kafka REST API endpoint."
  value       = confluent_kafka_cluster.this.rest_endpoint
}

output "cluster_api_version" {
  description = "Kafka cluster API version."
  value       = confluent_kafka_cluster.this.api_version
}

output "cluster_kind" {
  description = "Kafka cluster resource kind."
  value       = confluent_kafka_cluster.this.kind
}
