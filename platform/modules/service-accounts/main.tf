
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.0"
    }
  }
}

resource "confluent_service_account" "this" {
  for_each = var.service_accounts

  display_name = each.value.display_name
  description  = each.value.description
}
