
terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.0"
    }
  }
}

provider "confluent" {
  # Confluent Cloud authentication
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret

  # Kafka infrastructure retrieved from Platform remote state
  kafka_id            = local.platform_kafka_cluster_id
  kafka_rest_endpoint = local.platform_kafka_rest_endpoint

  # Kafka authentication credentials
  kafka_api_key    = var.kafka_api_key
  kafka_api_secret = var.kafka_api_secret
}
