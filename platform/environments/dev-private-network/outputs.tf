output "gateway_id" {
  description = "Private Link gateway ID; empty while networking is disabled."
  value       = try(confluent_gateway.dev[0].id, "")
}

output "private_link_service_alias" {
  description = "Confluent Private Link service alias the Azure endpoint connects to."
  value       = try(confluent_gateway.dev[0].azure_ingress_private_link_gateway[0].private_link_service_alias, "")
}

output "access_point_dns_domain" {
  description = "DNS domain for the private DNS zone."
  value       = try(confluent_access_point.dev[0].azure_ingress_private_link_endpoint[0].dns_domain, "")
}

output "private_cluster_id" {
  description = "Enterprise cluster ID; empty while the cluster is disabled."
  value       = try(confluent_kafka_cluster.private[0].id, "")
}
