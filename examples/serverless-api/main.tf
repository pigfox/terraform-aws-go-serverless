provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "terraform-aws-go-serverless"
      run_id  = var.run_id
      example = "serverless-api"
    }
  }
}

module "service" {
  source = "../../"

  name     = var.name
  run_id   = var.run_id
  zip_path = var.zip_path

  # Echoed back by the handler, so a caller can tell which deployment answered.
  environment_variables = { RUN_ID = var.run_id }

  # Two concurrent executions is plenty for a demo and caps what a flood of
  # requests can cost.
  reserved_concurrency = 2
}
