variable "run_id" {
  description = "Tag value identifying this deployment."
  type        = string
  default     = "prod"
}

variable "zip_path" {
  description = "Deployment zip; build it with ../../serverless-api/build.sh."
  type        = string
  default     = "../../serverless-api/build/bootstrap.zip"
}

variable "monthly_budget_usd" {
  description = "Monthly spend at which the budget alerts reach 100%."
  type        = number
  default     = 10
}

variable "alert_emails" {
  description = "Who gets the budget emails."
  type        = list(string)
  default     = ["ops@example.com"]
}
