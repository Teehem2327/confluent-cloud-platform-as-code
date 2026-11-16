# Schema Registry for test. This configuration does not create a registry.
# Switched off by default; set the registry values once it exists.

resource "terraform_data" "schema_deployment_guard" {
  count = var.deploy_schemas ? 1 : 0

  input = var.deploy_schemas

  lifecycle {
    precondition {
      condition = (
        length(trimspace(var.schema_registry_api_key)) > 0 &&
        length(trimspace(var.schema_registry_api_secret)) > 0 &&
        length(trimspace(var.schema_registry_cluster_id)) > 0 &&
        length(trimspace(var.schema_registry_rest_endpoint)) > 0
      )

      error_message = "Schema deployment requires Schema Registry credentials and endpoint."
    }
  }
}

resource "confluent_schema" "orders_value" {
  count = var.deploy_schemas ? 1 : 0

  schema_registry_cluster {
    id = var.schema_registry_cluster_id
  }

  rest_endpoint = var.schema_registry_rest_endpoint

  credentials {
    key    = var.schema_registry_api_key
    secret = var.schema_registry_api_secret
  }

  subject_name = "test.orders-value"
  format       = "AVRO"
  schema       = file("${path.module}/../../schemas/orders-value.avsc")

  depends_on = [
    terraform_data.schema_deployment_guard
  ]
}
