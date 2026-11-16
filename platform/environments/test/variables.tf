variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key for Terraform automation"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret for Terraform automation"
  type        = string
  sensitive   = true
  nullable    = false
}


variable "deploy_kafka_cluster" {
  description = "Controls whether the TEST Kafka cluster is provisioned."
  type        = bool
  default     = false
}


variable "deploy_service_accounts" {
  description = "Enable creation of TEST service accounts."
  type        = bool
  default     = false
}

variable "deploy_rbac" {
  description = "Enable TEST RBAC assignments."
  type        = bool
  default     = false
}

variable "deploy_kafka_api_keys" {
  type        = bool
  default     = false
  description = "Enable creation of TEST Kafka API keys."
}
