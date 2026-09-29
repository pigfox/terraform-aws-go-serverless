variable "name" {
  description = "Budget name, unique in the account."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,100}$", var.name))
    error_message = "name must be 1-100 letters, digits, underscores, dots or hyphens."
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

variable "monthly_limit_usd" {
  description = "Monthly spend, in US dollars, that the alert percentages are measured against."
  type        = number

  validation {
    condition     = var.monthly_limit_usd > 0
    error_message = "monthly_limit_usd must be greater than 0."
  }
}

variable "alert_emails" {
  description = "Addresses that receive the alerts. AWS sends a confirmation email to none of them; they simply start receiving mail."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0 && length(var.alert_emails) <= 10
    error_message = "alert_emails must contain between 1 and 10 addresses."
  }

  validation {
    condition     = alltrue([for e in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "each alert_emails entry must be an email address."
  }
}

variable "actual_thresholds" {
  description = "Percentages of the limit at which ACTUAL spend sends an alert."
  type        = list(number)
  default     = [50, 80, 100]

  validation {
    condition     = length(var.actual_thresholds) > 0 && alltrue([for t in var.actual_thresholds : t > 0 && t <= 1000])
    error_message = "actual_thresholds must be a non-empty list of percentages between 0 (exclusive) and 1000."
  }

  validation {
    condition     = length(distinct(var.actual_thresholds)) == length(var.actual_thresholds)
    error_message = "actual_thresholds must not repeat."
  }
}

variable "forecast_alert" {
  description = "Also alert when the month's FORECASTED spend passes 100% of the limit, which usually fires days before actual spend does."
  type        = bool
  default     = true
}

variable "cost_filter_tags" {
  description = "Only count spend on resources carrying these tags, e.g. { project = \"terraform-aws-go-serverless\" }. The tag keys must first be activated as cost allocation tags in the Billing console. Empty (the default) counts the whole account."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Extra tags for the budget. project and run_id are always set by the module and win over any value given here."
  type        = map(string)
  default     = {}
}
