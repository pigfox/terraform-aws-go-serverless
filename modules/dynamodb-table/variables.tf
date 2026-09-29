variable "name" {
  description = "Table name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", var.name))
    error_message = "name must be 3-255 characters of letters, digits, underscores, hyphens or dots."
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

variable "hash_key" {
  description = "Partition key attribute name."
  type        = string
  default     = "pk"
}

variable "hash_key_type" {
  description = "Partition key type: S (string), N (number) or B (binary)."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type must be S, N or B."
  }
}

variable "range_key" {
  description = "Optional sort key attribute name. null means a partition key only."
  type        = string
  default     = null
}

variable "range_key_type" {
  description = "Sort key type: S, N or B. Ignored when range_key is null."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "range_key_type must be S, N or B."
  }
}

variable "ttl_attribute" {
  description = "Attribute holding an epoch-seconds expiry. Items past it are deleted by DynamoDB for free. null disables TTL."
  type        = string
  default     = null
}

variable "point_in_time_recovery" {
  description = "Continuous backups with 35-day restore. Billed per GB stored, which is cents for a small table; on by default because losing a table is worse."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Refuse DeleteTable until this is turned off. Off by default so examples and tests can be torn down; turn it on for production."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for encryption at rest. null (the default) uses the AWS-owned key, which is free; a customer key costs about $1/month plus requests."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN or null."
  }
}

variable "tags" {
  description = "Extra tags for every resource. project and run_id are always set by the module and win over any value given here."
  type        = map(string)
  default     = {}
}
