variable "name" {
  description = "Base name for the service. Names the function, API, log groups and (when created) the table."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,56}$", var.name))
    error_message = "name must be 1-56 characters of letters, digits, hyphens or underscores (the IAM role adds a suffix)."
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
  description = "Path to the prebuilt deployment zip holding the Go bootstrap binary. See examples/serverless-api/build.sh."
  type        = string
}

variable "architecture" {
  description = "Instruction set the bootstrap binary was built for: arm64 (default, cheaper) or x86_64."
  type        = string
  default     = "arm64"
}

variable "memory_size" {
  description = "Function memory in MB."
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Function timeout in seconds. HTTP APIs stop waiting after 30."
  type        = number
  default     = 10

  validation {
    condition     = var.timeout <= 30
    error_message = "timeout above 30 seconds is pointless behind an HTTP API, which gives up at 30."
  }
}

variable "reserved_concurrency" {
  description = "Hard cap on concurrent executions (and so on spend). -1 leaves the function unreserved."
  type        = number
  default     = -1
}

variable "environment_variables" {
  description = "Plain environment variables for the function. TABLE_NAME is added automatically when create_table is true."
  type        = map(string)
  default     = {}

  validation {
    condition     = !contains(keys(var.environment_variables), "TABLE_NAME")
    error_message = "TABLE_NAME is set by the module when create_table is true."
  }
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the function may read at run time."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Retention for both the function logs and the API access logs."
  type        = number
  default     = 14
}

variable "routes" {
  description = "HTTP API route keys sent to the function. The default, \"$default\", sends everything."
  type        = list(string)
  default     = ["$default"]
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second before the API returns 429."
  type        = number
  default     = 10
}

variable "throttling_burst_limit" {
  description = "Burst requests above the steady rate."
  type        = number
  default     = 20
}

variable "cors_allow_origins" {
  description = "Browser origins allowed to call the API. Empty sends no CORS headers."
  type        = list(string)
  default     = []
}

variable "create_table" {
  description = "Create an on-demand DynamoDB table and give the function item-level access to it."
  type        = bool
  default     = false
}

variable "table_hash_key" {
  description = "Partition key of the table (string)."
  type        = string
  default     = "pk"
}

variable "table_range_key" {
  description = "Optional sort key of the table (string)."
  type        = string
  default     = null
}

variable "table_ttl_attribute" {
  description = "Optional TTL attribute of the table."
  type        = string
  default     = null
}

variable "table_point_in_time_recovery" {
  description = "Point-in-time recovery for the table."
  type        = bool
  default     = true
}

variable "table_deletion_protection" {
  description = "Deletion protection for the table. Turn on for production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags for every resource. project and run_id are always set and win over any value given here."
  type        = map(string)
  default     = {}
}
