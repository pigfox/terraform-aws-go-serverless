output "api_id" {
  description = "ID of the HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Base URL of the API, for example https://abc123.execute-api.us-east-1.amazonaws.com."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "execution_arn" {
  description = "Execution ARN of the API, for scoping further Lambda permissions."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "access_log_group_name" {
  description = "CloudWatch log group holding the access logs."
  value       = aws_cloudwatch_log_group.access.name
}
