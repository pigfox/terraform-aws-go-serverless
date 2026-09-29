variable "name" {
  description = "Name for the task family, ECR repository, cluster, log group (/ecs/<name>) and IAM roles."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]{0,47}$", var.name))
    error_message = "name must be 1-48 lowercase letters, digits, hyphens or underscores, starting with a letter or digit (ECR requires lowercase)."
  }
}

variable "run_id" {
  description = "Identifier stamped on every resource as the run_id tag, so everything one deployment created can be found (and proven gone) through the tagging API."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}$", var.run_id))
    error_message = "run_id must be 1-63 characters of lowercase letters, digits or hyphens, starting with a letter or digit."
  }
}

variable "image_tag" {
  description = "Tag of the image in the module's ECR repository to run. Tags are immutable, so a new build means a new tag and a new task definition revision."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.image_tag))
    error_message = "image_tag must be a valid Docker tag (up to 128 letters, digits, underscores, dots or hyphens)."
  }
}

variable "vpc_id" {
  description = "VPC the task's security group is created in."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must look like vpc-0123abcd."
  }
}

variable "subnet_ids" {
  description = "Subnets the task may be placed in. With no NAT gateway these must be public subnets and assign_public_ip must stay true, or the task cannot pull its image."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0 && alltrue([for s in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", s))])
    error_message = "subnet_ids must be a non-empty list of subnet IDs (subnet-0123abcd)."
  }
}

variable "assign_public_ip" {
  description = "Give the task a public IP. Required in a public subnet without a NAT gateway (the default design here); set false only if you provide NAT or VPC endpoints yourself."
  type        = bool
  default     = true
}

variable "allow_all_egress" {
  description = "Allow outbound traffic on every port. false (the default) allows only TCP 443, which is enough for ECR, CloudWatch Logs and HTTPS APIs."
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression, such as \"rate(1 day)\" or \"cron(0 3 * * ? *)\". null creates no schedule: the task is run-once, started with the run_task_command output."
  type        = string
  default     = null

  validation {
    condition     = var.schedule_expression == null || can(regex("^(rate|cron|at)\\(.+\\)$", var.schedule_expression))
    error_message = "schedule_expression must be rate(...), cron(...) or at(...)."
  }
}

variable "schedule_timezone" {
  description = "IANA time zone the cron expression is evaluated in."
  type        = string
  default     = "UTC"
}

variable "cpu" {
  description = "Task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be 256, 512, 1024, 2048 or 4096."
  }
}

variable "memory" {
  description = "Task memory in MiB. Must be a combination Fargate accepts for the chosen cpu."
  type        = number
  default     = 512

  validation {
    condition     = var.memory >= 512 && var.memory <= 30720 && var.memory % 512 == 0
    error_message = "memory must be a multiple of 512 between 512 and 30720 MiB."
  }
}

variable "architecture" {
  description = "CPU architecture of the image. ARM64 (Graviton) is about 20% cheaper per vCPU-hour on Fargate."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.architecture)
    error_message = "architecture must be ARM64 or X86_64."
  }
}

variable "command" {
  description = "Override the image's CMD. null keeps the image default."
  type        = list(string)
  default     = null
}

variable "environment_variables" {
  description = "Plain environment variables for the container. Do not put secrets here; use secrets."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Environment variable name to Secrets Manager secret ARN. ECS injects the value at start; the execution role may read exactly these ARNs."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for a in values(var.secrets) : can(regex("^arn:aws[a-z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", a))])
    error_message = "each secrets value must be a full Secrets Manager secret ARN with no wildcards."
  }
}

variable "ecr_keep_images" {
  description = "How many images the repository keeps; older ones are expired so storage does not grow forever."
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_keep_images >= 1 && floor(var.ecr_keep_images) == var.ecr_keep_images
    error_message = "ecr_keep_images must be a whole number >= 1."
  }
}

variable "force_delete_repository" {
  description = "Let terraform destroy delete the ECR repository while it still holds images."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the task's logs. Cannot be 0 (never expire)."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be one of the values CloudWatch Logs accepts (1, 3, 5, 7, 14, 30, 60, 90, ...), and not 0 (never expire)."
  }
}

variable "tags" {
  description = "Extra tags for every resource. project and run_id are always set by the module and win over any value given here."
  type        = map(string)
  default     = {}
}
