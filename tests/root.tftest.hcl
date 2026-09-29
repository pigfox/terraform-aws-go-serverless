# Root module (Lambda + HTTP API + optional DynamoDB) — mocked provider, no
# AWS account touched. See go_lambda.tftest.hcl for why the mock block is
# repeated per file, and http_api.tftest.hcl for why the wiring run is a mock
# apply.
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
  mock_resource "aws_lambda_function" {
    defaults = {
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:svc/invocations"
    }
  }
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123"
      api_endpoint  = "https://abc123.execute-api.us-east-1.amazonaws.com"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/mock" }
  }
}

variables {
  name     = "svc"
  run_id   = "test-run"
  zip_path = "tests/fixtures/bootstrap.zip"
}

run "defaults_have_no_table" {
  command = plan

  assert {
    condition     = length(module.table) == 0
    error_message = "the table must be opt-in"
  }

  assert {
    condition     = output.table_name == null && output.table_arn == null
    error_message = "table outputs must be null without a table"
  }

  assert {
    condition     = length(jsondecode(module.function.role_policy).Statement) == 1
    error_message = "without a table the function role must carry only its log statement"
  }
}

run "table_is_wired_to_function" {
  command = plan

  variables {
    create_table = true
  }

  assert {
    condition     = module.table[0].table_name == "svc"
    error_message = "the table must be named after the service"
  }

  assert {
    condition     = module.function.environment_variables["TABLE_NAME"] == "svc"
    error_message = "the function must be told the table name"
  }

  assert {
    condition     = jsondecode(module.function.role_policy).Statement[1].Resource == ["arn:aws:dynamodb:us-east-1:123456789012:table/svc", "arn:aws:dynamodb:us-east-1:123456789012:table/svc/index/*"]
    error_message = "table access must be scoped to this table and its indexes"
  }

  assert {
    condition     = !contains(jsondecode(module.function.role_policy).Statement[1].Action, "dynamodb:Scan") && !contains(jsondecode(module.function.role_policy).Statement[1].Action, "dynamodb:DeleteTable")
    error_message = "the function must not be able to scan or delete the table"
  }
}

run "wiring" {
  # Mock apply: the endpoint and invoke ARN are computed.
  command = apply

  assert {
    condition     = output.api_endpoint == "https://abc123.execute-api.us-east-1.amazonaws.com"
    error_message = "api_endpoint must come from the HTTP API"
  }
}

run "rejects_timeout_over_api_limit" {
  command = plan

  variables {
    timeout = 60
  }

  expect_failures = [var.timeout]
}

run "rejects_table_name_env_override" {
  command = plan

  variables {
    environment_variables = { TABLE_NAME = "other" }
  }

  expect_failures = [var.environment_variables]
}
