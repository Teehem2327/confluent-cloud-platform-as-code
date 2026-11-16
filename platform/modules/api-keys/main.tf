terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.0"
    }
  }
}

resource "confluent_api_key" "this" {
  for_each = var.api_keys

  display_name = each.value.display_name
  description  = each.value.description

  owner {
    id          = each.value.owner_id
    api_version = "iam/v2"
    kind        = "ServiceAccount"
  }

  managed_resource {
    id          = var.kafka_cluster_id
    api_version = var.kafka_cluster_api_version
    kind        = var.kafka_cluster_kind

    environment {
      id = var.environment_id
    }
  }
}
