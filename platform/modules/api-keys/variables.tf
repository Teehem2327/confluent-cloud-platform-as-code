variable "api_keys" {
  type = map(object({
    display_name = string
    description  = string
    owner_id     = string
  }))
}

variable "kafka_cluster_id" {
  type = string
}

variable "kafka_cluster_api_version" {
  type = string
}

variable "kafka_cluster_kind" {
  type = string
}

variable "environment_id" {
  type = string
}
