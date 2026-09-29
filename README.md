# terraform-aws-go-serverless

Terraform modules for running Go services on AWS for close to nothing: a Go
Lambda behind an HTTP API, an optional DynamoDB table, scheduled Fargate jobs,
a private S3 bucket, keyless GitHub Actions deploys, and a budget alarm. Every
module works on Terraform and OpenTofu.

> **Status: pre-release.** The mocked test suite passes on Terraform and
> OpenTofu in CI. **Live AWS verification is pending**: nothing here has yet been
> applied to a real account by this repo's own tests, and there is no tagged
> release. Read the plan before you apply.

## Quick start (30 seconds, plus a Go build)

You need Go 1.26+, `zip`, Terraform 1.10+ (or OpenTofu 1.10+), and AWS
credentials in your shell.

```sh
git clone https://github.com/pigfox/terraform-aws-go-serverless
cd terraform-aws-go-serverless/examples/serverless-api
./build.sh                       # builds build/bootstrap.zip for arm64
terraform init
terraform apply                  # review the plan, then type yes
curl "$(terraform output -raw api_endpoint)/hello"
terraform destroy                # when you are done
```

The response is a small JSON document from the Go handler in
[`examples/serverless-api/app`](examples/serverless-api/app). Idle, the whole
stack costs $0.00 a month.

To use the root module from your own code:

```hcl
module "service" {
  source = "github.com/pigfox/terraform-aws-go-serverless"

  name     = "orders"
  run_id   = "prod"
  zip_path = "build/bootstrap.zip"

  create_table = true # on-demand DynamoDB; the function gets item-level access
}
```

## Modules

| Module | What it creates | Idle cost | Cost when used (us-east-1, 2026 list prices) |
|---|---|---|---|
| [root](#root-module) | `go-lambda` + `http-api` + optional `dynamodb-table`, wired together | $0 | Sum of the three below |
| [`go-lambda`](modules/go-lambda) | Go Lambda on `provided.al2023`, arm64, log group, least-privilege role | $0 | Free tier: 1M requests + 400k GB-s/month; then ~$0.28 per 1M 50 ms requests at 128 MB |
| [`http-api`](modules/http-api) | API Gateway HTTP API, routes, stage, access logs, throttling | $0 | $1.00 per 1M requests |
| [`dynamodb-table`](modules/dynamodb-table) | On-demand table, PITR, TTL | $0 up to 25 GB | $0.625 per 1M writes, $0.125 per 1M reads; PITR $0.20/GB-month |
| [`s3-bucket`](modules/s3-bucket) | Private, TLS-only, encrypted, versioned bucket with lifecycle rules | $0 empty | $0.023/GB-month |
| [`fargate-task`](modules/fargate-task) | Scheduled or run-once Fargate task, ECR repo, no ALB, no NAT | $0 | ~$0.025/month for a 5-minute nightly run at 0.25 vCPU / 0.5 GB |
| [`github-oidc-role`](modules/github-oidc-role) | IAM role GitHub Actions assumes via OIDC, one repo, exact branches | $0 | $0 |
| [`budget-alarm`](modules/budget-alarm) | Monthly AWS Budgets cost budget with email alerts | $0 (first two budgets) | $0 |

Prices are approximate and change; check AWS's pricing pages for your region.

## What "cheap by default" means here

The defaults are chosen so an apply cannot quietly create something that bills
by the hour:

- **No NAT gateways, no load balancers, no EC2**, and no customer-managed KMS
  keys unless you pass one. Fargate tasks reach the internet from a public
  subnet with an egress-only security group instead of through NAT.
- **Every log group has a retention period**; "never expire" is rejected.
- **Throttling and concurrency caps** on the API and function, which also cap
  what a traffic spike can cost.
- **Every resource is tagged** `project = "terraform-aws-go-serverless"` and
  `run_id = <your value>`, so one deployment's resources can be listed (and
  proven gone) through the Resource Groups Tagging API.

## Security defaults

- IAM policies are written in the modules and fully visible in the plan: no
  managed policies, no wildcard actions, resources scoped to single ARNs. Where
  AWS itself offers no narrower resource (`ecr:GetAuthorizationToken`), the
  module says so in a comment and a test pins it as the only exception.
- S3 buckets are private with no switch to make them public, and refuse non-TLS requests.
- The GitHub OIDC role trusts one repository and exact branch names; wildcards,
  `AdministratorAccess` and `PowerUserAccess` are rejected.
- Secrets are granted by ARN and read at run time, so values never reach
  Terraform state.

## Examples

| Example | What it shows | What it costs |
|---|---|---|
| [`serverless-api`](examples/serverless-api) | Tiny Go handler, reproducible build script, the root module | $0 idle; ~$1.28 per million requests past the free tier |
| [`scheduled-fargate-job`](examples/scheduled-fargate-job) | Go job container on a nightly schedule in the default VPC | ~$0.04/month |
| [`ci-oidc`](examples/ci-oidc) | GitHub Actions deploying to Lambda with no stored keys | $0 |
| [`environments`](examples/environments) | dev and prod on the same modules, S3 state with native locking | $0 idle for both, plus cents for state |

## Testing

```sh
terraform test      # or: tofu test
```

Every module has a `tests/*.tftest.hcl` file run against a **mock AWS
provider**: no account, no credentials, no cost. They check defaults, input
validation (bad input must be rejected) and security properties (the bucket is
not public, the role has no wildcard, logs expire). Most runs are `plan`; the few
that check wiring between computed IDs use `apply` against the mock, because
that is the only way both Terraform and OpenTofu make computed values known.
Each file's run and assertion counts are declared in `tests/ASSERTIONS`, and CI
fails if they drift, so deleting a check cannot pass silently.

[`test/`](test) holds a Terratest suite that applies `examples/serverless-api`
for real, calls the endpoint, destroys it, and then asks the tagging API whether
anything with its `run_id` is left. It is skipped unless
`TERRATEST_LIVE=1` is set, and it creates billable resources when it runs.

CI runs formatting, `validate` on every module and example, tflint, a trivy
config scan, the mocked tests, and a terraform-docs drift check, with the
format/validate/test legs repeated on OpenTofu. It holds no AWS credentials.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
Licensed [MIT](LICENSE).

## Root module

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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| api | ./modules/http-api | n/a |
| function | ./modules/go-lambda | n/a |
| table | ./modules/dynamodb-table | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Base name for the service. Names the function, API, log groups and (when created) the table. | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| zip\_path | Path to the prebuilt deployment zip holding the Go bootstrap binary. See examples/serverless-api/build.sh. | `string` | n/a | yes |
| architecture | Instruction set the bootstrap binary was built for: arm64 (default, cheaper) or x86\_64. | `string` | `"arm64"` | no |
| cors\_allow\_origins | Browser origins allowed to call the API. Empty sends no CORS headers. | `list(string)` | `[]` | no |
| create\_table | Create an on-demand DynamoDB table and give the function item-level access to it. | `bool` | `false` | no |
| environment\_variables | Plain environment variables for the function. TABLE\_NAME is added automatically when create\_table is true. | `map(string)` | `{}` | no |
| log\_retention\_days | Retention for both the function logs and the API access logs. | `number` | `14` | no |
| memory\_size | Function memory in MB. | `number` | `128` | no |
| reserved\_concurrency | Hard cap on concurrent executions (and so on spend). -1 leaves the function unreserved. | `number` | `-1` | no |
| routes | HTTP API route keys sent to the function. The default, "$default", sends everything. | `list(string)` | ```[ "$default" ]``` | no |
| secret\_arns | Secrets Manager secret ARNs the function may read at run time. | `list(string)` | `[]` | no |
| table\_deletion\_protection | Deletion protection for the table. Turn on for production. | `bool` | `false` | no |
| table\_hash\_key | Partition key of the table (string). | `string` | `"pk"` | no |
| table\_point\_in\_time\_recovery | Point-in-time recovery for the table. | `bool` | `true` | no |
| table\_range\_key | Optional sort key of the table (string). | `string` | `null` | no |
| table\_ttl\_attribute | Optional TTL attribute of the table. | `string` | `null` | no |
| tags | Extra tags for every resource. project and run\_id are always set and win over any value given here. | `map(string)` | `{}` | no |
| throttling\_burst\_limit | Burst requests above the steady rate. | `number` | `20` | no |
| throttling\_rate\_limit | Steady-state requests per second before the API returns 429. | `number` | `10` | no |
| timeout | Function timeout in seconds. HTTP APIs stop waiting after 30. | `number` | `10` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| access\_log\_group\_name | CloudWatch log group of the API access logs. |
| api\_endpoint | Base URL of the HTTP API. curl it. |
| function\_arn | ARN of the Lambda function. |
| function\_log\_group\_name | CloudWatch log group of the function. |
| function\_name | Name of the Lambda function. |
| function\_role\_name | Name of the function's IAM role, for attaching further policies. |
| table\_arn | ARN of the DynamoDB table, or null when create\_table is false. |
| table\_name | Name of the DynamoDB table, or null when create\_table is false. |
<!-- END_TF_DOCS -->
