
locals {
  topics_test = {
    orders = {
      name           = "test.orders"
      partitions     = 3
      retention_ms   = "604800000"
      cleanup_policy = "delete"
    }

    payments = {
      name           = "test.payments"
      partitions     = 3
      retention_ms   = "604800000"
      cleanup_policy = "delete"
    }
  }

  acls_test = {
    application_orders_read = {
      resource_type = "TOPIC"
      resource_name = "test.orders"
      pattern_type  = "LITERAL"
      principal     = local.application_acl_principal
      host          = "*"
      operation     = "READ"
      permission    = "ALLOW"
    }

    application_orders_write = {
      resource_type = "TOPIC"
      resource_name = "test.orders"
      pattern_type  = "LITERAL"
      principal     = local.application_acl_principal
      host          = "*"
      operation     = "WRITE"
      permission    = "ALLOW"
    }

    application_consumer_group_read = {
      resource_type = "GROUP"
      resource_name = "test.orders-consumers"
      pattern_type  = "LITERAL"
      principal     = local.application_acl_principal
      host          = "*"
      operation     = "READ"
      permission    = "ALLOW"
    }
  }
}

# Construct the ACL principal from the Platform service account.
locals {
  application_acl_principal = trimspace(local.platform_application_service_account_id) != "" ? "User:${local.platform_application_service_account_id}" : ""
}

# Prevent deployment when required infrastructure or credentials are missing.
resource "terraform_data" "application_deployment_guard" {
  count = var.deploy_application_resources ? 1 : 0

  input = var.deploy_application_resources

  lifecycle {
    precondition {
      condition = !var.deploy_application_resources || (
        length(trimspace(local.platform_kafka_cluster_id)) > 0 &&
        length(trimspace(local.platform_kafka_rest_endpoint)) > 0 &&
        length(trimspace(local.platform_application_service_account_id)) > 0 &&
        length(trimspace(var.kafka_api_key)) > 0 &&
        length(trimspace(var.kafka_api_secret)) > 0 &&
        length(trimspace(var.confluent_cloud_api_key)) > 0 &&
        length(trimspace(var.confluent_cloud_api_secret)) > 0
      )

      error_message = "Application deployment requires Platform Kafka outputs, an application service account, and valid Confluent Cloud/Kafka API credentials."
    }
  }
}

# Manage Kafka topics only when deployment is enabled.
module "topics" {
  source = "../../modules/topics"

  topics = var.deploy_application_resources ? local.topics_test : {}

  kafka_cluster_id    = local.platform_kafka_cluster_id
  kafka_rest_endpoint = local.platform_kafka_rest_endpoint

  depends_on = [
    terraform_data.application_deployment_guard
  ]
}

# Manage Kafka ACLs after the deployment guard and topics.
module "acls" {
  source = "../../modules/acls"

  acls = var.deploy_application_resources ? local.acls_test : {}

  kafka_cluster_id    = local.platform_kafka_cluster_id
  kafka_rest_endpoint = local.platform_kafka_rest_endpoint

  depends_on = [
    terraform_data.application_deployment_guard,
    module.topics
  ]
}
