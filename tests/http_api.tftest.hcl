# modules/http-api — mocked provider, no AWS account touched.
# See go_lambda.tftest.hcl for why the mock block is repeated per file.
#
# Most runs are plan. The one run that asserts wiring between computed values
# (the API's execution ARN, the integration ID, the log group ARN) uses
# `command = apply`, which here applies against the MOCK provider only: nothing
# is created anywhere. It has to, because Terraform leaves computed values
# unknown during plan unless `override_during = plan` is set, and OpenTofu
# rejects that argument. Mock apply is the one form both tools accept.
mock_provider "aws" {
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "abc123"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123"
      api_endpoint  = "https://abc123.execute-api.us-east-1.amazonaws.com"
    }
  }
  mock_resource "aws_apigatewayv2_integration" {
    defaults = { id = "int123" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/apigateway/hello" }
  }
}

variables {
  name                 = "hello"
  run_id               = "test-run"
  lambda_function_name = "hello"
  lambda_invoke_arn    = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:hello/invocations"
}

run "defaults" {
  command = plan

  module {
    source = "./modules/http-api"
  }

  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP"
    error_message = "must be an HTTP API (the cheap kind), not REST"
  }

  assert {
    condition     = keys(aws_apigatewayv2_route.this) == ["$default"]
    error_message = "default routing must be a single $default route"
  }

  assert {
    condition     = aws_apigatewayv2_integration.lambda.payload_format_version == "2.0"
    error_message = "integration must use payload format 2.0"
  }

  assert {
    condition     = aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit == 10 && aws_apigatewayv2_stage.default.default_route_settings[0].throttling_burst_limit == 20
    error_message = "stage must be throttled by default (10 rps, burst 20)"
  }

  assert {
    condition     = aws_cloudwatch_log_group.access.retention_in_days == 14
    error_message = "access logs must expire"
  }

  assert {
    condition     = length(aws_apigatewayv2_api.this.cors_configuration) == 0
    error_message = "no CORS configuration unless origins are named"
  }

  assert {
    condition     = aws_apigatewayv2_api.this.tags["run_id"] == "test-run" && aws_apigatewayv2_stage.default.tags["project"] == "terraform-aws-go-serverless"
    error_message = "api and stage must carry the project and run_id tags"
  }
}

run "wiring_and_permission_scope" {
  # Mock apply, see the header: these values are computed.
  command = apply

  module {
    source = "./modules/http-api"
  }

  assert {
    condition     = aws_apigatewayv2_route.this["$default"].target == "integrations/int123"
    error_message = "the route must target the Lambda integration"
  }

  assert {
    condition     = aws_apigatewayv2_stage.default.access_log_settings[0].destination_arn == "arn:aws:logs:us-east-1:123456789012:log-group:/aws/apigateway/hello"
    error_message = "access logs must go to the module's own log group"
  }

  assert {
    condition     = output.api_endpoint == "https://abc123.execute-api.us-east-1.amazonaws.com"
    error_message = "api_endpoint output must be the API's endpoint"
  }

  assert {
    condition     = aws_lambda_permission.api.source_arn == "arn:aws:execute-api:us-east-1:123456789012:abc123/*/*"
    error_message = "invoke permission must be limited to this API's execution ARN"
  }

  assert {
    condition     = aws_lambda_permission.api.principal == "apigateway.amazonaws.com" && aws_lambda_permission.api.action == "lambda:InvokeFunction"
    error_message = "permission must grant only lambda:InvokeFunction to API Gateway"
  }
}

run "explicit_routes_and_cors" {
  command = plan

  module {
    source = "./modules/http-api"
  }

  variables {
    routes             = ["GET /items", "POST /items"]
    cors_allow_origins = ["https://example.com"]
  }

  assert {
    condition     = length(aws_apigatewayv2_route.this) == 2
    error_message = "one route per key"
  }

  assert {
    condition     = aws_apigatewayv2_api.this.cors_configuration[0].allow_origins == toset(["https://example.com"])
    error_message = "CORS origins must be passed through exactly"
  }
}

run "rejects_bad_route" {
  command = plan

  module {
    source = "./modules/http-api"
  }

  variables {
    routes = ["FETCH /items"]
  }

  expect_failures = [var.routes]
}

run "rejects_wildcard_cors" {
  command = plan

  module {
    source = "./modules/http-api"
  }

  variables {
    cors_allow_origins = ["*"]
  }

  expect_failures = [var.cors_allow_origins]
}

run "rejects_function_arn_as_invoke_arn" {
  command = plan

  module {
    source = "./modules/http-api"
  }

  variables {
    lambda_invoke_arn = "arn:aws:lambda:us-east-1:123456789012:function:hello"
  }

  expect_failures = [var.lambda_invoke_arn]
}

run "rejects_zero_throttle" {
  command = plan

  module {
    source = "./modules/http-api"
  }

  variables {
    throttling_rate_limit = 0
  }

  expect_failures = [var.throttling_rate_limit]
}
