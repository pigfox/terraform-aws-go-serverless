output "role_arn" {
  description = "ARN to put in the workflow's aws-actions/configure-aws-credentials role-to-assume."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the role."
  value       = aws_iam_role.this.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider the role trusts."
  value       = local.provider_arn
}

output "trusted_subjects" {
  description = "The exact token subjects allowed to assume the role."
  value       = local.subjects
}
