output "role_arn" {
  description = "Put this in the workflow's role-to-assume. It is not a secret."
  value       = module.deploy_role.role_arn
}

output "trusted_subjects" {
  description = "Exactly which workflow runs may assume the role."
  value       = module.deploy_role.trusted_subjects
}
