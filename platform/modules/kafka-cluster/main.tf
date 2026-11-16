

terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.0"
    }
  }
}

resource "confluent_kafka_cluster" "this" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud
  region       = var.region

  environment {
    id = var.environment_id
  }

  dynamic "basic" {
    for_each = var.cluster_type == "BASIC" ? [1] : []
    content {}
  }

  dynamic "standard" {
    for_each = var.cluster_type == "STANDARD" ? [1] : []
    content {}
  }

  dynamic "enterprise" {
    for_each = var.cluster_type == "ENTERPRISE" ? [1] : []
    content {}
  }
}
