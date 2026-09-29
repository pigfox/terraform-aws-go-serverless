output "table_name" {
  description = "Name of the table."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the table, for IAM policies."
  value       = aws_dynamodb_table.this.arn
}

output "crud_actions" {
  description = "The item-level actions a typical service needs on this table, for passing to go-lambda's policy_statements. Deliberately excludes table management and scans."
  value = [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem",
    "dynamodb:Query",
    "dynamodb:BatchGetItem",
    "dynamodb:BatchWriteItem",
  ]
}
