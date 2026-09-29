# modules/budget-alarm — plan-only, mocked provider, no AWS account touched.
# See go_lambda.tftest.hcl for why the mock block is repeated per file.
mock_provider "aws" {}

variables {
  name              = "monthly"
  run_id            = "test-run"
  monthly_limit_usd = 5
  alert_emails      = ["ops@example.com"]
}

run "defaults" {
  command = plan

  module {
    source = "./modules/budget-alarm"
  }

  assert {
    condition     = aws_budgets_budget.this.budget_type == "COST" && aws_budgets_budget.this.time_unit == "MONTHLY"
    error_message = "must be a monthly cost budget"
  }

  assert {
    condition     = aws_budgets_budget.this.limit_amount == "5.00" && aws_budgets_budget.this.limit_unit == "USD"
    error_message = "limit must be the given dollars, formatted as AWS stores it"
  }

  assert {
    condition     = length(aws_budgets_budget.this.notification) == 4
    error_message = "defaults must give three actual alerts (50/80/100) and one forecast alert"
  }

  assert {
    condition     = length([for n in aws_budgets_budget.this.notification : n if n.notification_type == "FORECASTED" && n.threshold == 100]) == 1
    error_message = "a forecast alert at 100% must be on by default"
  }

  assert {
    condition     = sort([for n in aws_budgets_budget.this.notification : tostring(n.threshold) if n.notification_type == "ACTUAL"]) == tolist(["100", "50", "80"])
    error_message = "actual alerts must default to 50, 80 and 100 percent"
  }

  assert {
    condition     = alltrue([for n in aws_budgets_budget.this.notification : n.subscriber_email_addresses == toset(["ops@example.com"])])
    error_message = "every alert must go to the given addresses"
  }

  assert {
    condition     = length(aws_budgets_budget.this.cost_filter) == 0
    error_message = "no cost filter unless tags are given"
  }

  assert {
    condition     = aws_budgets_budget.this.tags["project"] == "terraform-aws-go-serverless" && aws_budgets_budget.this.tags["run_id"] == "test-run"
    error_message = "budget must carry the project and run_id tags"
  }
}

run "tag_filter_and_no_forecast" {
  command = plan

  module {
    source = "./modules/budget-alarm"
  }

  variables {
    forecast_alert    = false
    actual_thresholds = [90]
    cost_filter_tags  = { project = "terraform-aws-go-serverless" }
  }

  assert {
    condition     = length(aws_budgets_budget.this.notification) == 1
    error_message = "only the one actual alert"
  }

  assert {
    condition     = tolist(one(aws_budgets_budget.this.cost_filter).values) == tolist(["user:project$terraform-aws-go-serverless"])
    error_message = "tag filter must use the user:<key>$<value> form Budgets expects"
  }
}

run "rejects_zero_limit" {
  command = plan

  module {
    source = "./modules/budget-alarm"
  }

  variables {
    monthly_limit_usd = 0
  }

  expect_failures = [var.monthly_limit_usd]
}

run "rejects_no_emails" {
  command = plan

  module {
    source = "./modules/budget-alarm"
  }

  variables {
    alert_emails = []
  }

  expect_failures = [var.alert_emails]
}

run "rejects_bad_email" {
  command = plan

  module {
    source = "./modules/budget-alarm"
  }

  variables {
    alert_emails = ["not-an-address"]
  }

  expect_failures = [var.alert_emails]
}
