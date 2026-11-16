
output "service_account_ids" {
  description = "Service account IDs indexed by logical name."

  value = {
    for name, account in confluent_service_account.this :
    name => account.id
  }
}

output "service_account_principals" {
  description = "RBAC principal strings indexed by logical name."

  value = {
    for name, account in confluent_service_account.this :
    name => "User:${account.id}"
  }
}
