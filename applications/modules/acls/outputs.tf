output "acl_ids" {
  description = "ACL IDs by logical name."
  value       = { for name, acl in confluent_kafka_acl.this : name => acl.id }
}
