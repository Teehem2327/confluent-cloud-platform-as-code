variable "deploy_schemas" {
  description = "Enable DEV schema registration explicitly."
  type        = bool
  default     = false
}

variable "schema_registry_cluster_id" {
  description = "Existing DEV Schema Registry ID."
  type        = string
  default     = "lsrc-xxxxxx"
}

variable "schema_registry_rest_endpoint" {
  description = "Existing DEV Schema Registry endpoint."
  type        = string
  default     = "https://psrc-xxxxxx.eastus.azure.confluent.cloud"
}

variable "schema_registry_api_key" {
  description = "Schema Registry API key."
  type        = string
  sensitive   = true
  default     = ""
}

variable "schema_registry_api_secret" {
  description = "Schema Registry API secret."
  type        = string
  sensitive   = true
  default     = ""
}
