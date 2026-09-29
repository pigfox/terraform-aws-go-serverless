locals {
  tags = merge(var.tags, {
    project = "terraform-aws-go-serverless"
    run_id  = var.run_id
  })

  notifications = concat(
    [for t in var.actual_thresholds : { type = "ACTUAL", threshold = t }],
    var.forecast_alert ? [{ type = "FORECASTED", threshold = 100 }] : [],
  )
}

resource "aws_budgets_budget" "this" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = format("%.2f", var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "cost_filter" {
    for_each = length(var.cost_filter_tags) == 0 ? [] : [1]
    content {
      name = "TagKeyValue"
      # Budgets' tag syntax is user:<key>$<value>. format() keeps the literal
      # "$" away from HCL's "$${" escape, which would print the template text.
      values = [for k in sort(keys(var.cost_filter_tags)) : format("user:%s$%s", k, var.cost_filter_tags[k])]
    }
  }

  dynamic "notification" {
    for_each = local.notifications
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = var.alert_emails
    }
  }

  tags = local.tags
}
