# Sensitive values remain in Terraform state. Restrict backend access.
# Operational copies are synchronized to Azure Key Vault by the DEV Apply pipeline.
output "dev_kafka_api_key_credentials" {
  description = "DEV Kafka API key IDs and secrets for secure Key Vault synchronization."
  sensitive   = true
  value = {
    for role, key_id in module.api_keys.api_key_ids :
    role => {
      key    = key_id
      secret = module.api_keys.api_key_secrets[role]
    }
  }
}
