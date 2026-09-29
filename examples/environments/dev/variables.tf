variable "run_id" {
  description = "Tag value identifying this deployment."
  type        = string
  default     = "dev"
}

variable "zip_path" {
  description = "Deployment zip; build it with ../../serverless-api/build.sh."
  type        = string
  default     = "../../serverless-api/build/bootstrap.zip"
}
