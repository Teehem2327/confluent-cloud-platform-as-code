output "api_key_ids" {
  description = "Kafka API key IDs, indexed by logical name."

  value = {
    for name, key in confluent_api_key.this :
    name => key.id
  }
}

output "api_key_secrets" {
  description = "Sensitive Kafka API key secrets."

  sensitive = true

  value = {
    for name, key in confluent_api_key.this :
    name => key.secret
  }
}
