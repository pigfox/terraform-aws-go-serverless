variable "role_name" {
  description = "Name of the IAM role GitHub Actions will assume."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.role_name))
    error_message = "role_name must be 1-64 characters valid in an IAM role name."
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

variable "github_repository" {
  description = "The one repository allowed to assume the role, as owner/name. Wildcards are rejected: a role trusting \"owner/*\" trusts every repository that owner will ever create."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be exactly owner/name, with no wildcards."
  }
}

variable "branches" {
  description = "Branches whose workflow runs may assume the role. Exact names only."
  type        = list(string)
  default     = ["main"]

  validation {
    condition     = alltrue([for b in var.branches : can(regex("^[A-Za-z0-9._/-]+$", b))])
    error_message = "branches must be exact branch names; wildcards are not allowed."
  }
}

variable "environments" {
  description = "GitHub deployment environments whose jobs may assume the role. An environment with required reviewers is the strongest gate GitHub offers."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[A-Za-z0-9._-]+$", e))])
    error_message = "environments must be exact environment names; wildcards are not allowed."
  }
}

variable "allow_pull_requests" {
  description = "Also trust pull_request workflow runs. Off by default: a pull request runs the proposer's code, so only enable this for a read-only role."
  type        = bool
  default     = false
}

variable "create_oidc_provider" {
  description = "Create the account's GitHub OIDC identity provider. An account can have only one per URL, so set false and pass oidc_provider_arn if it already exists."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of an existing token.actions.githubusercontent.com identity provider. Used only when create_oidc_provider is false."
  type        = string
  default     = null

  validation {
    condition     = var.oidc_provider_arn == null || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be the ARN of the token.actions.githubusercontent.com provider."
  }
}

variable "policy_arns" {
  description = "Managed policy ARNs to attach to the role. AdministratorAccess and PowerUserAccess are rejected; grant what the pipeline deploys, not everything."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.policy_arns : can(regex("^arn:aws[a-z-]*:iam::(aws|[0-9]{12}):policy/", a))])
    error_message = "policy_arns entries must be IAM policy ARNs."
  }

  validation {
    condition     = alltrue([for a in var.policy_arns : !can(regex(":policy/(AdministratorAccess|PowerUserAccess)$", a))])
    error_message = "AdministratorAccess and PowerUserAccess may not be attached to a CI role."
  }
}

variable "inline_policy_json" {
  description = "Optional inline policy document (JSON) for the role. Statements whose Action is \"*\" are rejected."
  type        = string
  default     = null

  validation {
    condition     = var.inline_policy_json == null || can(jsondecode(var.inline_policy_json).Statement)
    error_message = "inline_policy_json must be a JSON policy document with a Statement list."
  }

  validation {
    condition = var.inline_policy_json == null || !can(jsondecode(var.inline_policy_json).Statement) || alltrue([
      for s in try(jsondecode(var.inline_policy_json).Statement, []) :
      !contains(flatten([try(s.Action, [])]), "*")
    ])
    error_message = "inline_policy_json may not allow Action \"*\"."
  }
}

variable "max_session_duration" {
  description = "Maximum session length in seconds. One hour covers almost every deploy job."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary for the role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags for every resource. project and run_id are always set by the module and win over any value given here."
  type        = map(string)
  default     = {}
}
