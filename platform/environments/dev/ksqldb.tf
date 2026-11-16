# DEV fully managed ksqlDB cluster.
# Disabled by default. It is billed hourly for as long as it exists, so deploy it
# only through the approval-gated platform-dev-ksqldb-apply pipeline.

variable "deploy_ksqldb" {
  description = "Enable the DEV ksqlDB cluster. Billable while it exists."
  type        = bool
  default     = false
}

variable "ksqldb_csu" {
  description = "Confluent Streaming Units for the DEV ksqlDB cluster."
  type        = number
  default     = 4
}

resource "confluent_ksql_cluster" "dev" {
  count = var.deploy_ksqldb ? 1 : 0

  display_name = "ksql-dev"
  csu          = var.ksqldb_csu

  kafka_cluster {
    id = module.kafka_cluster[0].cluster_id
  }

  credential_identity {
    id = module.service_accounts.service_account_ids["platform"]
  }

  environment {
    id = confluent_environment.dev.id
  }

  depends_on = [
    module.kafka_cluster,
    module.security,
    module.api_keys
  ]
}

output "ksqldb_cluster_id" {
  description = "DEV ksqlDB cluster ID; empty while ksqlDB is disabled."
  value       = length(confluent_ksql_cluster.dev) > 0 ? confluent_ksql_cluster.dev[0].id : ""
}

output "ksqldb_rest_endpoint" {
  description = "DEV ksqlDB REST endpoint; empty while ksqlDB is disabled."
  value       = length(confluent_ksql_cluster.dev) > 0 ? confluent_ksql_cluster.dev[0].rest_endpoint : ""
}
