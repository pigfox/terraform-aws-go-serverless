variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "run_id" {
  description = "Tag value identifying this deployment."
  type        = string
  default     = "example"
}

variable "github_repository" {
  description = "The repository whose main branch may deploy, as owner/name."
  type        = string
  default     = "your-org/your-repo"
}

variable "function_name" {
  description = "The Lambda function the pipeline may update (for example the one examples/serverless-api creates)."
  type        = string
  default     = "go-serverless-hello"
}

variable "create_oidc_provider" {
  description = "Create the account's GitHub OIDC provider. false if it already exists."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "Existing provider ARN, when create_oidc_provider is false."
  type        = string
  default     = null
}
