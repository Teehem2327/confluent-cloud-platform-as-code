# DEV Schema Registry API key managed by Terraform (replaces the key created by hand in the console).
# Disabled by default. The key is created by the approval-gated
# platform-dev-schema-registry-key pipeline, which then stores it in Azure Key Vault.
# The secret is kept in Terraform state, so restrict access to the state storage.

variable "deploy_schema_registry_api_key" {
  description = "Enable the Terraform-managed DEV Schema Registry API key."
  type        = bool
  default     = true
}

data "confluent_schema_registry_cluster" "dev" {
  count = var.deploy_schema_registry_api_key ? 1 : 0

  environment {
    id = confluent_environment.dev.id
  }
}

resource "confluent_api_key" "schema_registry" {
  count = var.deploy_schema_registry_api_key ? 1 : 0

  display_name = "dev-schema-registry-terraform-key"
  description  = "Schema Registry API key for DEV Terraform automation."

  owner {
    id          = module.service_accounts.service_account_ids["platform"]
    api_version = "iam/v2"
    kind        = "ServiceAccount"
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.dev[0].id
    api_version = data.confluent_schema_registry_cluster.dev[0].api_version
    kind        = data.confluent_schema_registry_cluster.dev[0].kind

    environment {
      id = confluent_environment.dev.id
    }
  }
}

output "dev_schema_registry_api_key_credentials" {
  description = "DEV Schema Registry API key ID and secret for secure Key Vault synchronization."
  sensitive   = true
  value = length(confluent_api_key.schema_registry) > 0 ? {
    key    = confluent_api_key.schema_registry[0].id
    secret = confluent_api_key.schema_registry[0].secret
  } : null
}
