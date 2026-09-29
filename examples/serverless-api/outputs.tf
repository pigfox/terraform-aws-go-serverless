output "api_endpoint" {
  description = "Base URL of the API. curl it."
  value       = module.service.api_endpoint
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = module.service.function_name
}
