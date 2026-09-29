output "api_endpoint" {
  description = "Base URL of the HTTP API. curl it."
  value       = module.api.api_endpoint
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = module.function.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = module.function.function_arn
}

output "function_role_name" {
  description = "Name of the function's IAM role, for attaching further policies."
  value       = module.function.role_name
}

output "function_log_group_name" {
  description = "CloudWatch log group of the function."
  value       = module.function.log_group_name
}

output "access_log_group_name" {
  description = "CloudWatch log group of the API access logs."
  value       = module.api.access_log_group_name
}

output "table_name" {
  description = "Name of the DynamoDB table, or null when create_table is false."
  value       = var.create_table ? module.table[0].table_name : null
}

output "table_arn" {
  description = "ARN of the DynamoDB table, or null when create_table is false."
  value       = var.create_table ? module.table[0].table_arn : null
}
