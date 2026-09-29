# http-api

An API Gateway HTTP API in front of one Lambda function: routes, a
`$default` stage that deploys automatically, JSON access logs with a retention
period, throttling, and the one Lambda permission the API needs.

HTTP APIs are the cheaper kind of API Gateway API (about a third of the price of
REST APIs) and are all a Lambda-backed JSON service needs.

```hcl
module "api" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/http-api"

  name                 = "orders"
  run_id               = "prod"
  lambda_function_name = module.function.function_name
  lambda_invoke_arn    = module.function.invoke_arn

  routes                = ["GET /orders", "POST /orders"]
  throttling_rate_limit = 50
}
```

## What it costs

Nothing while idle. $1.00 per million requests (the first million a month are free
for an account's first 12 months). Access logs are $0.50 per GB ingested.
(us-east-1 list prices, 2026.)

## Security defaults

- Throttled out of the box: 10 requests per second, burst 20. Every request is
  billed, so raising this is a decision rather than an accident.
- The Lambda permission is scoped to this API's execution ARN, not to every API
  Gateway in the account.
- No CORS headers unless origins are named, and `"*"` is rejected.
- Access-log retention cannot be set to "never expire".

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_apigatewayv2_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_permission.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| lambda\_function\_name | Name of the Lambda function the routes invoke. The module grants API Gateway permission to invoke it from this API only. | `string` | n/a | yes |
| lambda\_invoke\_arn | Invoke ARN of the Lambda function (the go-lambda module's invoke\_arn output). | `string` | n/a | yes |
| name | Name of the HTTP API. Also names its access-log group (/aws/apigateway/<name>). | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| cors\_allow\_origins | Origins allowed to call the API from a browser. Empty (the default) sends no CORS headers at all. "*" is rejected; name the origins. | `list(string)` | `[]` | no |
| log\_retention\_days | How long CloudWatch keeps the access logs. Cannot be 0 (never expire). | `number` | `14` | no |
| routes | Route keys sent to the function, such as "GET /items" or "$default" (everything). Routing inside one Go binary is usually simpler than one route per path. | `list(string)` | ```[ "$default" ]``` | no |
| tags | Extra tags for every resource. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |
| throttling\_burst\_limit | Requests the stage accepts in a burst above the steady rate. | `number` | `20` | no |
| throttling\_rate\_limit | Steady-state requests per second the stage accepts before returning 429. Low by default because every request is billed; raise it deliberately. | `number` | `10` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| access\_log\_group\_name | CloudWatch log group holding the access logs. |
| api\_endpoint | Base URL of the API, for example https://abc123.execute-api.us-east-1.amazonaws.com. |
| api\_id | ID of the HTTP API. |
| execution\_arn | Execution ARN of the API, for scoping further Lambda permissions. |
<!-- END_TF_DOCS -->
