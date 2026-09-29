variable "name" {
  description = "Function name. Also names the IAM role and the log group (/aws/lambda/<name>)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.name))
    error_message = "name must be 1-64 characters of letters, digits, hyphens or underscores."
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

variable "zip_path" {
  description = "Path to a prebuilt deployment zip whose root holds an executable named bootstrap (a Go binary built for provided.al2023). The module never builds code."
  type        = string

  validation {
    condition     = endswith(var.zip_path, ".zip")
    error_message = "zip_path must point at a .zip file."
  }
}

variable "architecture" {
  description = "Instruction set the bootstrap binary was built for. arm64 (Graviton) is about 20% cheaper per GB-second than x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be arm64 or x86_64."
  }
}

variable "memory_size" {
  description = "Memory in MB. CPU scales with memory; 128 is enough for most small Go handlers."
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240 && floor(var.memory_size) == var.memory_size
    error_message = "memory_size must be a whole number between 128 and 10240."
  }
}

variable "timeout" {
  description = "Maximum run time per invocation, in seconds. API Gateway HTTP APIs give up after 30."
  type        = number
  default     = 10

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900 && floor(var.timeout) == var.timeout
    error_message = "timeout must be a whole number of seconds between 1 and 900."
  }
}

variable "reserved_concurrency" {
  description = "Hard cap on concurrent executions, which is also a hard cap on spend. -1 leaves the function unreserved."
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrency >= -1 && floor(var.reserved_concurrency) == var.reserved_concurrency
    error_message = "reserved_concurrency must be -1 (unreserved) or a whole number >= 0."
  }
}

variable "environment_variables" {
  description = "Plain environment variables for the function. Do not put secrets here: they are visible in the console and in state. Use secret_arns instead."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.environment_variables) : can(regex("^[A-Za-z][A-Za-z0-9_]*$", k))])
    error_message = "environment variable names must start with a letter and contain only letters, digits and underscores."
  }

  validation {
    condition     = !contains(keys(var.environment_variables), "AWS_REGION") && !contains(keys(var.environment_variables), "AWS_LAMBDA_FUNCTION_NAME")
    error_message = "AWS_REGION and AWS_LAMBDA_FUNCTION_NAME are reserved by Lambda."
  }
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the function may read with secretsmanager:GetSecretValue. Only these exact ARNs are granted; the function reads them at run time, so values never enter Terraform state."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.secret_arns : can(regex("^arn:aws[a-z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", a))])
    error_message = "each secret_arns entry must be a full Secrets Manager secret ARN with no wildcards."
  }
}

variable "policy_statements" {
  description = "Extra IAM Allow statements for the function role, for example DynamoDB access to one table. Wildcard actions (\"*\" or \"service:*\") and a bare \"*\" resource are rejected."
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))
  default = []

  validation {
    condition = alltrue(flatten([
      for s in var.policy_statements : [for a in s.actions : can(regex("^[a-z0-9-]+:[A-Za-z0-9]+$", a))]
    ]))
    error_message = "policy_statements actions must be explicit service:Action names; wildcards are not allowed."
  }

  validation {
    condition     = alltrue(flatten([for s in var.policy_statements : [for r in s.resources : r != "*"]]))
    error_message = "policy_statements resources must be ARNs, not \"*\"."
  }

  validation {
    condition     = alltrue([for s in var.policy_statements : length(s.actions) > 0 && length(s.resources) > 0])
    error_message = "every policy statement needs at least one action and one resource."
  }
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the function's logs. Never-expiring logs are a slow, silent cost, so this cannot be 0."
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
