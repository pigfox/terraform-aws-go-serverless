provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project     = "terraform-aws-go-serverless"
      run_id      = var.run_id
      environment = "prod"
    }
  }
}

# prod: the same modules as dev with different inputs. The table is protected
# and recoverable, logs are kept for a month, the API accepts more traffic, and
# a budget emails before the bill surprises anyone.
module "service" {
  source = "../../../"

  name     = "go-serverless-prod"
  run_id   = var.run_id
  zip_path = var.zip_path

  environment_variables = { APP_ENV = "prod", RUN_ID = var.run_id }

  create_table                 = true
  table_point_in_time_recovery = true
  table_deletion_protection    = true

  memory_size            = 256
  log_retention_days     = 30
  reserved_concurrency   = 20
  throttling_rate_limit  = 50
  throttling_burst_limit = 100
}

module "budget" {
  source = "../../../modules/budget-alarm"

  name              = "go-serverless-prod"
  run_id            = var.run_id
  monthly_limit_usd = var.monthly_budget_usd
  alert_emails      = var.alert_emails
}
