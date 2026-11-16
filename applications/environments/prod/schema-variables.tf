variable "deploy_schemas" {
  description = "Enable prod schema registration explicitly."
  type        = bool
  default     = false
}

variable "schema_registry_cluster_id" {
  description = "prod Schema Registry ID. Empty until the registry exists."
  type        = string
  default     = ""
}

variable "schema_registry_rest_endpoint" {
  description = "prod Schema Registry endpoint. Empty until the registry exists."
  type        = string
  default     = ""
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
