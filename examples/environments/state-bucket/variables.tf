variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "run_id" {
  description = "Tag value identifying this deployment."
  type        = string
  default     = "state"
}

variable "bucket_name" {
  description = "Globally unique name for the state bucket. Change it: bucket names are shared by every AWS account."
  type        = string
  default     = "change-me-tf-state-go-serverless"
}
