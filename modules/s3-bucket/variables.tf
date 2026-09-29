variable "name" {
  description = "Bucket name. Must be globally unique across all AWS accounts."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.name)) && !strcontains(var.name, "..")
    error_message = "name must be a valid S3 bucket name: 3-63 lowercase letters, digits, dots or hyphens, starting and ending with a letter or digit."
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

variable "versioning" {
  description = "Keep previous versions of overwritten or deleted objects. On by default; old versions expire after noncurrent_version_expiration_days so they do not accumulate cost forever."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which a superseded object version is deleted. Only applies when versioning is on."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1 && floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days
    error_message = "noncurrent_version_expiration_days must be a whole number >= 1."
  }
}

variable "abort_incomplete_multipart_days" {
  description = "Days after which unfinished multipart uploads are discarded. Their parts are billed but invisible in the console."
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_days >= 1 && floor(var.abort_incomplete_multipart_days) == var.abort_incomplete_multipart_days
    error_message = "abort_incomplete_multipart_days must be a whole number >= 1."
  }
}

variable "lifecycle_rules" {
  description = "Additional expiration rules, each for a key prefix. Example: { id = \"tmp\", prefix = \"tmp/\", expiration_days = 1 }."
  type = list(object({
    id              = string
    prefix          = string
    expiration_days = number
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.lifecycle_rules : r.expiration_days >= 1 && can(regex("^[A-Za-z0-9_-]{1,64}$", r.id))])
    error_message = "each lifecycle rule needs an id of 1-64 letters, digits, hyphens or underscores and expiration_days >= 1."
  }

  validation {
    condition     = !contains([for r in var.lifecycle_rules : r.id], "baseline")
    error_message = "the rule id \"baseline\" is reserved by the module."
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for SSE-KMS. null (the default) uses SSE-S3 (AES-256), which is free."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN or null."
  }
}

variable "access_log_bucket" {
  description = "Name of an existing bucket to receive server access logs. null (the default) disables access logging."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Let terraform destroy delete a bucket that still holds objects. Off by default: a data bucket should not vanish with its contents by accident."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags for every resource. project and run_id are always set by the module and win over any value given here."
  type        = map(string)
  default     = {}
}
