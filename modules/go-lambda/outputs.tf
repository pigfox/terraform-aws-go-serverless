output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN API Gateway uses to invoke the function."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_name" {
  description = "Name of the function's IAM role, for attaching further policies outside the module."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN of the function's IAM role."
  value       = aws_iam_role.this.arn
}

output "role_policy" {
  description = "The role's inline policy document as JSON, for review or policy-as-code checks."
  value       = aws_iam_role_policy.this.policy
}

output "environment_variables" {
  description = "The plain environment variables the function was given."
  value       = var.environment_variables
}

output "log_group_name" {
  description = "CloudWatch log group the function writes to."
  value       = aws_cloudwatch_log_group.this.name
}
