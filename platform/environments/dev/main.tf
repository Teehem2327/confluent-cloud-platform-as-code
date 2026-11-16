resource "confluent_environment" "dev" {
  display_name = "dev"
}

# Kafka cluster deployment is disabled by default.
# Enable only after reviewing the Terraform plan and costs.

module "kafka_cluster" {
  source = "../../modules/kafka-cluster"

  count = var.deploy_kafka_cluster ? 1 : 0

  cluster_name   = "kafka-dev"
  environment_id = confluent_environment.dev.id

  cloud        = "AZURE"
  region       = "eastus"
  cluster_type = "STANDARD"
  availability = "SINGLE_ZONE"
}


locals {
  dev_service_accounts = {
    platform = {
      display_name = "sa-dev-platform"
      description  = "Platform automation identity for DEV."
    }

    application = {
      display_name = "sa-dev-application"
      description  = "Application workload identity for DEV."
    }
  }
}

module "service_accounts" {
  source = "../../modules/service-accounts"

  service_accounts = (
    var.deploy_service_accounts
    ? local.dev_service_accounts
    : {}
  )
}

locals {
  # Environment-level administrative access is optional.
  # The application account receives no permissions yet.
  dev_role_bindings = var.deploy_rbac ? {
    platform_environment_admin = {
      principal = module.service_accounts.service_account_principals["platform"]

      role_name = "EnvironmentAdmin"

      crn_pattern = confluent_environment.dev.resource_name
    }
  } : {}
}

module "security" {
  source = "../../modules/security"

  role_bindings = local.dev_role_bindings
}


# DEV Kafka API keys.
# Existing Kafka cluster and service accounts must already be deployed.

locals {
  dev_kafka_api_keys = var.deploy_kafka_api_keys ? {
    platform = {
      display_name = "dev-platform-kafka-api-key"
      description  = "Kafka API key for DEV Terraform automation."
      owner_id     = module.service_accounts.service_account_ids["platform"]
    }

    application = {
      display_name = "dev-application-kafka-api-key"
      description  = "Kafka API key for DEV application workloads."
      owner_id     = module.service_accounts.service_account_ids["application"]
    }
  } : {}
}

module "api_keys" {
  source = "../../modules/api-keys"

  api_keys = local.dev_kafka_api_keys

  kafka_cluster_id          = try(module.kafka_cluster[0].cluster_id, "")
  kafka_cluster_api_version = try(module.kafka_cluster[0].cluster_api_version, "")
  kafka_cluster_kind        = try(module.kafka_cluster[0].cluster_kind, "")

  environment_id = confluent_environment.dev.id

  depends_on = [
    module.kafka_cluster,
    module.service_accounts,
    module.security
  ]
}
