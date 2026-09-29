provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "terraform-aws-go-serverless"
      run_id  = var.run_id
      example = "ci-oidc"
    }
  }
}

data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  function_arn = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.function_name}"
}

module "deploy_role" {
  source = "../../modules/github-oidc-role"

  role_name         = "${var.function_name}-deploy"
  run_id            = var.run_id
  github_repository = var.github_repository
  branches          = ["main"]

  # Set false if the account already has the GitHub OIDC provider (an account
  # can hold only one), and pass its ARN as oidc_provider_arn.
  create_oidc_provider = var.create_oidc_provider
  oidc_provider_arn    = var.oidc_provider_arn

  # The pipeline may ship new code to one function and read it back. It
  # cannot create, delete or reconfigure anything.
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ShipCodeToOneFunction"
      Effect   = "Allow"
      Action   = ["lambda:UpdateFunctionCode", "lambda:GetFunction"]
      Resource = [local.function_arn]
    }]
  })
}
