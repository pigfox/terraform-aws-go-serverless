# modules/go-lambda — plan-only, mocked provider, no AWS account touched.
#
# The mock block is repeated in every test file on purpose: OpenTofu does not
# support `source` on mock_provider, and every test must run on both tools.
# Terraform leaves computed attributes unknown during plan; OpenTofu fills them
# with generated strings and validates them, so ARN-shaped attributes get
# well-formed values here. 123456789012 is AWS's documentation account.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock-role" }
  }
}

variables {
  name     = "hello"
  run_id   = "test-run"
  zip_path = "tests/fixtures/bootstrap.zip"
}

run "defaults" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  assert {
    condition     = aws_lambda_function.this.runtime == "provided.al2023"
    error_message = "runtime must be provided.al2023"
  }

  assert {
    condition     = aws_lambda_function.this.handler == "bootstrap"
    error_message = "handler must be bootstrap"
  }

  assert {
    condition     = aws_lambda_function.this.architectures == tolist(["arm64"])
    error_message = "default architecture must be arm64"
  }

  assert {
    condition     = aws_lambda_function.this.memory_size == 128 && aws_lambda_function.this.timeout == 10
    error_message = "default memory and timeout must be 128 MB and 10 s"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 14
    error_message = "log group must default to 14 days of retention"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/aws/lambda/hello"
    error_message = "log group must be the function's own /aws/lambda/<name>"
  }

  assert {
    condition     = aws_lambda_function.this.tags["project"] == "terraform-aws-go-serverless" && aws_lambda_function.this.tags["run_id"] == "test-run"
    error_message = "function must carry the project and run_id tags"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.tags["run_id"] == "test-run" && aws_iam_role.this.tags["run_id"] == "test-run"
    error_message = "log group and role must carry the run_id tag"
  }

  assert {
    condition     = length(aws_lambda_function.this.environment) == 0
    error_message = "no environment block should be rendered when no variables are given"
  }
}

run "role_is_least_privilege" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.this.policy).Statement) == 1
    error_message = "with no secrets or extras, the role must carry exactly one statement"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.this.policy).Statement[0].Resource == ["arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/hello:*"]
    error_message = "log permission must be scoped to the function's own log group"
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.this.policy).Statement : [for a in s.Action : !strcontains(a, "*")]
    ]))
    error_message = "no action in the role policy may contain a wildcard"
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.this.policy).Statement : [for r in s.Resource : r != "*"]
    ]))
    error_message = "no resource in the role policy may be a bare wildcard"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
    error_message = "only the Lambda service may assume the role"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "123456789012"
    error_message = "the trust policy must be pinned to the deploying account"
  }
}

run "secrets_and_env" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    architecture          = "x86_64"
    environment_variables = { LOG_LEVEL = "debug" }
    secret_arns           = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:app/db-AbCdEf"]
  }

  assert {
    condition     = aws_lambda_function.this.architectures == tolist(["x86_64"])
    error_message = "architecture must be overridable"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["LOG_LEVEL"] == "debug"
    error_message = "environment variables must reach the function"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.this.policy).Statement[1].Action == ["secretsmanager:GetSecretValue"]
    error_message = "secret access must be read-only"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.this.policy).Statement[1].Resource == ["arn:aws:secretsmanager:us-east-1:123456789012:secret:app/db-AbCdEf"]
    error_message = "secret access must name exactly the given ARNs"
  }
}

run "extra_statements" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    policy_statements = [{
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
      resources = ["arn:aws:dynamodb:us-east-1:123456789012:table/items"]
    }]
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.this.policy).Statement[1].Resource == ["arn:aws:dynamodb:us-east-1:123456789012:table/items"]
    error_message = "extra statements must be appended as given"
  }
}

run "rejects_wildcard_action" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    policy_statements = [{
      actions   = ["dynamodb:*"]
      resources = ["arn:aws:dynamodb:us-east-1:123456789012:table/items"]
    }]
  }

  expect_failures = [var.policy_statements]
}

run "rejects_wildcard_resource" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    policy_statements = [{
      actions   = ["dynamodb:GetItem"]
      resources = ["*"]
    }]
  }

  expect_failures = [var.policy_statements]
}

run "rejects_wildcard_secret" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    secret_arns = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:*"]
  }

  expect_failures = [var.secret_arns]
}

run "rejects_never_expiring_logs" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    log_retention_days = 0
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_bad_architecture" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    architecture = "arm"
  }

  expect_failures = [var.architecture]
}

run "rejects_bad_run_id" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    run_id = "Has Spaces"
  }

  expect_failures = [var.run_id]
}

run "rejects_memory_out_of_range" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    memory_size = 64
  }

  expect_failures = [var.memory_size]
}

run "rejects_reserved_env_var" {
  command = plan

  module {
    source = "./modules/go-lambda"
  }

  variables {
    environment_variables = { AWS_REGION = "eu-west-1" }
  }

  expect_failures = [var.environment_variables]
}
