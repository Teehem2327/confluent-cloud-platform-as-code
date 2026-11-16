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

variable "azure_subscription_id" {
  description = "Azure subscription that will hold the private endpoint and DNS zone."
  type        = string
  nullable    = false
}

variable "azure_region" {
  description = "Azure region. Must match the Confluent gateway and cluster region."
  type        = string
  default     = "eastus"
}

variable "deploy_private_networking" {
  description = "Enable the gateway, Azure private endpoint, DNS and access point. Billable while it exists."
  type        = bool
  default     = false
}

variable "deploy_private_cluster" {
  description = "Enable the Enterprise cluster that uses the private network. Billed hourly while it exists."
  type        = bool
  default     = false
}

variable "vnet_address_space" {
  description = "Address space of the VNet that holds the private endpoint."
  type        = string
  default     = "10.60.0.0/16"
}

variable "endpoint_subnet_prefix" {
  description = "Subnet prefix for the private endpoint."
  type        = string
  default     = "10.60.1.0/24"
}

variable "resource_group_name" {
  description = "Pre-created resource group for the private networking resources. The pipeline identity needs Contributor on this group only."
  type        = string
  default     = "rg-confluent-private-dev"
}
