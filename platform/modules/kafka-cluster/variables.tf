
variable "cluster_name" {
  description = "Display name of the Confluent Cloud Kafka cluster."
  type        = string
}

variable "environment_id" {
  description = "ID of the existing Confluent Cloud environment."
  type        = string
}

variable "cloud" {
  description = "Cloud provider for the Kafka cluster."
  type        = string
  default     = "AZURE"

  validation {
    condition     = contains(["AWS", "AZURE", "GCP"], var.cloud)
    error_message = "Cloud must be AWS, AZURE, or GCP."
  }
}

variable "region" {
  description = "Confluent Cloud region."
  type        = string
  default     = "eastus"
}

variable "cluster_type" {
  description = "Kafka cluster type."
  type        = string
  default     = "BASIC"

  validation {
    condition = contains(
      ["BASIC", "STANDARD", "ENTERPRISE"],
      var.cluster_type
    )
    error_message = "Cluster type must be BASIC, STANDARD, or ENTERPRISE."
  }
}

variable "availability" {
  description = "Availability configuration for supported cluster types."
  type        = string
  default     = "SINGLE_ZONE"

  validation {
    condition = contains(
      ["SINGLE_ZONE", "MULTI_ZONE"],
      var.availability
    )
    error_message = "Availability must be SINGLE_ZONE or MULTI_ZONE."
  }
}
