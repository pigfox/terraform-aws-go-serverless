variable "name" {
  description = "Name of the HTTP API. Also names its access-log group (/aws/apigateway/<name>)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,128}$", var.name))
    error_message = "name must be 1-128 characters of letters, digits, hyphens or underscores."
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

variable "lambda_function_name" {
  description = "Name of the Lambda function the routes invoke. The module grants API Gateway permission to invoke it from this API only."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function (the go-lambda module's invoke_arn output)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:apigateway:", var.lambda_invoke_arn))
    error_message = "lambda_invoke_arn must be a Lambda invoke ARN (arn:aws:apigateway:...), not the function ARN."
  }
}

variable "routes" {
  description = "Route keys sent to the function, such as \"GET /items\" or \"$default\" (everything). Routing inside one Go binary is usually simpler than one route per path."
  type        = list(string)
  default     = ["$default"]

  validation {
    condition     = length(var.routes) > 0
    error_message = "routes must contain at least one route key."
  }

  validation {
    condition     = alltrue([for r in var.routes : can(regex("^(\\$default|(ANY|GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) /[^ ]*)$", r))])
    error_message = "each route must be \"$default\" or \"METHOD /path\" with METHOD one of ANY, GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS."
  }

  validation {
    condition     = length(distinct(var.routes)) == length(var.routes)
    error_message = "routes must not repeat."
  }
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second the stage accepts before returning 429. Low by default because every request is billed; raise it deliberately."
  type        = number
  default     = 10

  validation {
    condition     = var.throttling_rate_limit > 0 && var.throttling_rate_limit <= 10000
    error_message = "throttling_rate_limit must be greater than 0 and at most 10000."
  }
}

variable "throttling_burst_limit" {
  description = "Requests the stage accepts in a burst above the steady rate."
  type        = number
  default     = 20

  validation {
    condition     = var.throttling_burst_limit >= 1 && var.throttling_burst_limit <= 5000 && floor(var.throttling_burst_limit) == var.throttling_burst_limit
    error_message = "throttling_burst_limit must be a whole number between 1 and 5000."
  }
}

variable "cors_allow_origins" {
  description = "Origins allowed to call the API from a browser. Empty (the default) sends no CORS headers at all. \"*\" is rejected; name the origins."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for o in var.cors_allow_origins : can(regex("^https?://[^*/]+$", o))])
    error_message = "each CORS origin must be a scheme and host such as https://example.com, with no path and no wildcard."
  }
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the access logs. Cannot be 0 (never expire)."
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
