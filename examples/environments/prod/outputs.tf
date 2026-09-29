output "api_endpoint" {
  description = "Base URL of the prod API."
  value       = module.service.api_endpoint
}

output "table_name" {
  description = "The prod table."
  value       = module.service.table_name
}
