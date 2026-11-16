output "topic_ids" {
  value       = module.topics.topic_ids
  description = "Managed topic IDs."
}
output "acl_ids" {
  value       = module.acls.acl_ids
  description = "Managed ACL IDs."
}
