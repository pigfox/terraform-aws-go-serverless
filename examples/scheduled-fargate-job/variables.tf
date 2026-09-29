variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the job."
  type        = string
  default     = "go-nightly-job"
}

variable "run_id" {
  description = "Tag value identifying this deployment."
  type        = string
  default     = "example"
}

variable "image_tag" {
  description = "Image tag to run; push it with ./build-and-push.sh <tag>."
  type        = string
  default     = "v1"
}

variable "schedule_expression" {
  description = "When the job runs. null makes it run-once (use the run_task_command output)."
  type        = string
  default     = "cron(0 3 * * ? *)"
}
