resource "confluent_environment" "prod" {
  display_name = "prod"
}

# Kafka cluster deployment is disabled by default.
# Enable only after reviewing the Terraform plan and costs.

module "kafka_cluster" {
  source = "../../modules/kafka-cluster"

  count = var.deploy_kafka_cluster ? 1 : 0

  cluster_name   = "kafka-prod"
  environment_id = confluent_environment.prod.id

  cloud        = "AZURE"
  region       = "eastus"
  cluster_type = "BASIC"
  availability = "SINGLE_ZONE"
}


locals {
  service_accounts_prod = {
    platform = {
      display_name = "sa-prod-platform"
      description  = "Platform automation identity for PROD."
    }

    application = {
      display_name = "sa-prod-application"
      description  = "Application workload identity for PROD."
    }
  }
}

module "service_accounts" {
  source = "../../modules/service-accounts"

  service_accounts = (
    var.deploy_service_accounts
    ? local.service_accounts_prod
    : {}
  )
}

locals {
  # Environment-level administrative access is optional.
  # The application account receives no permissions yet.
  role_bindings_prod = var.deploy_rbac ? {
    platform_environment_admin = {
      principal = module.service_accounts.service_account_principals["platform"]

      role_name = "EnvironmentAdmin"

      crn_pattern = confluent_environment.prod.resource_name
    }
  } : {}
}

module "security" {
  source = "../../modules/security"

  role_bindings = local.role_bindings_prod
}


# PROD Kafka API keys.
# Existing Kafka cluster and service accounts must already be deployed.

locals {
  prod_kafka_api_keys = var.deploy_kafka_api_keys ? {
    platform = {
      display_name = "prod-platform-kafka-api-key"
      description  = "Kafka API key for PROD Terraform automation."
      owner_id     = module.service_accounts.service_account_ids["platform"]
    }

    application = {
      display_name = "prod-application-kafka-api-key"
      description  = "Kafka API key for PROD application workloads."
      owner_id     = module.service_accounts.service_account_ids["application"]
    }
  } : {}
}

module "api_keys" {
  source = "../../modules/api-keys"

  api_keys = local.prod_kafka_api_keys

  kafka_cluster_id          = try(module.kafka_cluster[0].cluster_id, "")
  kafka_cluster_api_version = try(module.kafka_cluster[0].cluster_api_version, "")
  kafka_cluster_kind        = try(module.kafka_cluster[0].cluster_kind, "")

  environment_id = confluent_environment.prod.id

  depends_on = [
    module.kafka_cluster,
    module.service_accounts,
    module.security
  ]
}
