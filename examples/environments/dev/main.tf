provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project     = "terraform-aws-go-serverless"
      run_id      = var.run_id
      environment = "dev"
    }
  }
}

# dev: smallest everything, short log retention, no deletion protection, so
# the whole environment can be destroyed and recreated freely. Point-in-time
# recovery stays on: for a dev-sized table it costs cents.
module "service" {
  source = "../../../"

  name     = "go-serverless-dev"
  run_id   = var.run_id
  zip_path = var.zip_path

  environment_variables = { APP_ENV = "dev", RUN_ID = var.run_id }

  create_table              = true
  table_deletion_protection = false

  log_retention_days     = 3
  reserved_concurrency   = 2
  throttling_rate_limit  = 5
  throttling_burst_limit = 10
}
