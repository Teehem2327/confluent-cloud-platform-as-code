variable "confluent_cloud_api_key" {
  type      = string
  sensitive = true
  default   = ""
}
variable "confluent_cloud_api_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "kafka_api_key" {
  type      = string
  sensitive = true
  default   = ""
}
variable "kafka_api_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "kafka_cluster_id" {
  type    = string
  default = ""
}
variable "kafka_rest_endpoint" {
  type    = string
  default = ""
}
variable "application_service_account_id" {
  type    = string
  default = ""
}
variable "deploy_application_resources" {
  type        = bool
  default     = false
  description = "Disabled until platform resources and Kafka credentials are ready."
}
