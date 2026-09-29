# go-lambda

A Go binary on AWS Lambda's `provided.al2023` runtime, on arm64 by default.
You build the code; this module deploys it. It creates the function, its log
group with a retention period, and an IAM role that can write to that one log
group and nothing else until you say otherwise.

```hcl
module "function" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/go-lambda"

  name     = "orders"
  run_id   = "prod"
  zip_path = "build/bootstrap.zip" # a zip whose root holds an executable named bootstrap

  environment_variables = { LOG_LEVEL = "info" }
  secret_arns           = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:orders/db-AbCdEf"]
}
```

Build the zip with `GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -tags lambda.norpc -o bootstrap`
and zip the result; [`examples/serverless-api/build.sh`](../../examples/serverless-api/build.sh)
does it reproducibly.

## What it costs

Nothing while idle. Lambda's free tier covers 1M requests and 400,000 GB-seconds a
month. Past that, arm64 is $0.20 per million requests plus about $0.0000133 per
GB-second: a 128 MB function answering in 50 ms costs roughly $0.28 per million
requests. Logs are $0.50 per GB ingested; retention stops them piling up.
(us-east-1 list prices, 2026. Check the AWS pricing page for your region.)

## Security defaults

- The role's policy is built in the module and visible in the plan: write to
  `/aws/lambda/<name>` only. No managed policies, no wildcards.
- The trust policy lets only `lambda.amazonaws.com` assume the role, and only on
  behalf of the deploying account (`aws:SourceAccount`).
- `secret_arns` grants `secretsmanager:GetSecretValue` on exactly those ARNs; a
  wildcard ARN is rejected. The function reads secrets at run time, so their
  values never enter Terraform state.
- `policy_statements` rejects wildcard actions and a bare `"*"` resource.
- Log retention cannot be set to "never expire".

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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Function name. Also names the IAM role and the log group (/aws/lambda/<name>). | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| zip\_path | Path to a prebuilt deployment zip whose root holds an executable named bootstrap (a Go binary built for provided.al2023). The module never builds code. | `string` | n/a | yes |
| architecture | Instruction set the bootstrap binary was built for. arm64 (Graviton) is about 20% cheaper per GB-second than x86\_64. | `string` | `"arm64"` | no |
| environment\_variables | Plain environment variables for the function. Do not put secrets here: they are visible in the console and in state. Use secret\_arns instead. | `map(string)` | `{}` | no |
| log\_retention\_days | How long CloudWatch keeps the function's logs. Never-expiring logs are a slow, silent cost, so this cannot be 0. | `number` | `14` | no |
| memory\_size | Memory in MB. CPU scales with memory; 128 is enough for most small Go handlers. | `number` | `128` | no |
| policy\_statements | Extra IAM Allow statements for the function role, for example DynamoDB access to one table. Wildcard actions ("*" or "service:*") and a bare "*" resource are rejected. | ```list(object({ actions = list(string) resources = list(string) }))``` | `[]` | no |
| reserved\_concurrency | Hard cap on concurrent executions, which is also a hard cap on spend. -1 leaves the function unreserved. | `number` | `-1` | no |
| secret\_arns | Secrets Manager secret ARNs the function may read with secretsmanager:GetSecretValue. Only these exact ARNs are granted; the function reads them at run time, so values never enter Terraform state. | `list(string)` | `[]` | no |
| tags | Extra tags for every resource. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |
| timeout | Maximum run time per invocation, in seconds. API Gateway HTTP APIs give up after 30. | `number` | `10` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| environment\_variables | The plain environment variables the function was given. |
| function\_arn | ARN of the Lambda function. |
| function\_name | Name of the Lambda function. |
| invoke\_arn | ARN API Gateway uses to invoke the function. |
| log\_group\_name | CloudWatch log group the function writes to. |
| role\_arn | ARN of the function's IAM role. |
| role\_name | Name of the function's IAM role, for attaching further policies outside the module. |
| role\_policy | The role's inline policy document as JSON, for review or policy-as-code checks. |
<!-- END_TF_DOCS -->
