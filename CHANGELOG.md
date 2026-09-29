# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions will
follow [Semantic Versioning](https://semver.org/) once the first release is tagged.

## [Unreleased]

### Added

- Root module: a Go Lambda behind an API Gateway HTTP API, with an optional
  on-demand DynamoDB table the function gets item-level access to.
- `modules/go-lambda`: `provided.al2023` on arm64 by default, prebuilt zip,
  log group with retention, least-privilege role, optional environment
  variables and Secrets Manager read access by ARN.
- `modules/http-api`: HTTP API, routes, `$default` stage, JSON access logs,
  throttling, Lambda permission scoped to the API.
- `modules/dynamodb-table`: on-demand table, point-in-time recovery toggle, TTL.
- `modules/s3-bucket`: private bucket, public access blocked, SSE-S3, TLS-only
  policy, versioning toggle, lifecycle rules.
- `modules/fargate-task`: scheduled or run-once Fargate task with an ECR
  repository, EventBridge Scheduler schedule, egress-only security group, no
  load balancer and no NAT gateway.
- `modules/github-oidc-role`: IAM role for GitHub Actions via OIDC, scoped to one
  repository and exact branches or environments.
- `modules/budget-alarm`: monthly AWS Budgets cost budget with email alerts.
- Examples: `serverless-api`, `scheduled-fargate-job`, `ci-oidc`,
  `environments` (dev and prod, S3 backend with native lock files).
- Mocked `terraform test` suites for every module, run on Terraform and OpenTofu.
- A Terratest suite for `examples/serverless-api`, gated behind `TERRATEST_LIVE=1`.
- CI: fmt, validate, tflint, trivy, mocked tests, terraform-docs drift check,
  Go checks, repository hygiene.
- `tests/ASSERTIONS` and `scripts/assert-count.sh`: each test file's run,
  assert and `expect_failures` counts are declared, and CI fails on any
  difference or on a vacuous `condition = true`, so a removed assertion turns
  the build red instead of quietly proving less.

### Not yet done

- Live verification against a real AWS account (the Terratest suite has not run).
- No release has been tagged and nothing is published to the Terraform Registry.
