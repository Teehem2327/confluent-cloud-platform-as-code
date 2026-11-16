
output "role_binding_ids" {
  description = "Terraform-managed role binding IDs."

  value = {
    for name, binding in confluent_role_binding.this :
    name => binding.id
  }
}
