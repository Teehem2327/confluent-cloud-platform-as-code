output "topic_ids" {
  description = "Topic IDs by logical name."
  value       = { for name, topic in confluent_kafka_topic.this : name => topic.id }
}
