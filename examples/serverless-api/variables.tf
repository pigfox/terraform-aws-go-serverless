variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the service."
  type        = string
  default     = "go-serverless-hello"
}

variable "run_id" {
  description = "Tag value identifying this deployment. Terratest sets a random one per run."
  type        = string
  default     = "example"
}

variable "zip_path" {
  description = "Deployment zip produced by ./build.sh."
  type        = string
  default     = "build/bootstrap.zip"
}
