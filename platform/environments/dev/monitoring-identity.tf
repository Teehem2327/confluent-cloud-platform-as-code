# DEV read-only monitoring identity for the Dynatrace collector.
# Replaces the broad Global Cloud key with a service account that can only read metrics
# (MetricsViewer role) and a Cloud resource-management key owned by that account.
# Disabled by default. It is created by the approval-gated platform-dev-monitoring-identity
# pipeline, which then stores the key in Azure Key Vault. The secret is also kept in Terraform
# state, so restrict access to the state storage.

variable "deploy_monitoring_identity" {
  description = "Enable the DEV read-only monitoring service account, role binding and key."
  type        = bool
  default     = true
}

data "confluent_organization" "main" {
  count = var.deploy_monitoring_identity ? 1 : 0
}

resource "confluent_service_account" "monitoring" {
  count = var.deploy_monitoring_identity ? 1 : 0

  display_name = "sa-dev-monitoring"
  description  = "Read-only metrics identity for the DEV Dynatrace collector."
}

# The organization CRN must not end with a trailing slash, or Confluent returns HTTP 400.
resource "confluent_role_binding" "monitoring_metrics_viewer" {
  count = var.deploy_monitoring_identity ? 1 : 0

  principal   = "User:${confluent_service_account.monitoring[0].id}"
  role_name   = "MetricsViewer"
  crn_pattern = "crn://confluent.cloud/organization=${data.confluent_organization.main[0].id}"
}

resource "confluent_api_key" "monitoring" {
  count = var.deploy_monitoring_identity ? 1 : 0

  display_name = "dev-monitoring-metrics-key"
  description  = "Cloud resource-management key for reading Confluent metrics."

  owner {
    id          = confluent_service_account.monitoring[0].id
    api_version = confluent_service_account.monitoring[0].api_version
    kind        = confluent_service_account.monitoring[0].kind
  }

  depends_on = [confluent_role_binding.monitoring_metrics_viewer]
}

output "dev_monitoring_api_key_credentials" {
  description = "DEV monitoring API key ID and secret for secure Key Vault synchronization."
  sensitive   = true
  value = length(confluent_api_key.monitoring) > 0 ? {
    key    = confluent_api_key.monitoring[0].id
    secret = confluent_api_key.monitoring[0].secret
  } : null
}
