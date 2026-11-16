
# Read the Platform Terraform state.
# Authentication is supplied by the local Azure CLI or pipeline OIDC environment.

data "terraform_remote_state" "platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = "storage"
    storage_account_name = "sttfstateexample01"
    container_name       = "tfstate"
    key                  = "platform-prod.tfstate"

    use_azuread_auth = true
  }
}

locals {
  platform_environment_id = data.terraform_remote_state.platform.outputs.environment_id

  platform_kafka_cluster_id = data.terraform_remote_state.platform.outputs.kafka_cluster_id

  platform_kafka_rest_endpoint = data.terraform_remote_state.platform.outputs.kafka_rest_endpoint

  platform_application_service_account_id = data.terraform_remote_state.platform.outputs.application_service_account_id
}
