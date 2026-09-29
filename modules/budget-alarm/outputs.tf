output "budget_name" {
  description = "Name of the budget."
  value       = aws_budgets_budget.this.name
}

output "limit_amount" {
  description = "The monthly limit as AWS stores it (a decimal string in USD)."
  value       = aws_budgets_budget.this.limit_amount
}
