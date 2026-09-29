# github-oidc-role

An IAM role that GitHub Actions can assume through OIDC, so a workflow gets
one-hour AWS credentials without any stored access keys. The trust policy names
one repository and exact branches, environments, or (opt-in) pull requests.

```hcl
module "deploy_role" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/github-oidc-role"

  role_name         = "orders-deploy"
  run_id            = "prod"
  github_repository = "example-org/orders"
  branches          = ["main"]
  environments      = ["production"]

  inline_policy_json = data.aws_iam_policy_document.deploy.json
}
```

In the workflow, grant `id-token: write` and use
`aws-actions/configure-aws-credentials` with `role-to-assume` set to the
`role_arn` output. [`examples/ci-oidc`](../../examples/ci-oidc) has a complete
workflow.

An AWS account can hold only one OIDC provider for
`token.actions.githubusercontent.com`. The module creates it by default; if it
already exists, set `create_oidc_provider = false` and pass `oidc_provider_arn`.

## What it costs

Nothing. IAM roles and OIDC providers are free.

## Security defaults

- One repository, named exactly. `owner/*` is rejected.
- Exact subjects matched with `StringEquals`: no `StringLike`, no wildcards in
  branch or environment names.
- The audience is pinned to `sts.amazonaws.com`.
- Pull-request runs are **not** trusted unless `allow_pull_requests = true`,
  because a pull request runs the proposer's code.
- The role starts with no permissions. `AdministratorAccess` and
  `PowerUserAccess` are rejected, as is an inline policy allowing `Action: "*"`.
- Sessions last one hour by default.

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
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| github\_repository | The one repository allowed to assume the role, as owner/name. Wildcards are rejected: a role trusting "owner/*" trusts every repository that owner will ever create. | `string` | n/a | yes |
| role\_name | Name of the IAM role GitHub Actions will assume. | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| allow\_pull\_requests | Also trust pull\_request workflow runs. Off by default: a pull request runs the proposer's code, so only enable this for a read-only role. | `bool` | `false` | no |
| branches | Branches whose workflow runs may assume the role. Exact names only. | `list(string)` | ```[ "main" ]``` | no |
| create\_oidc\_provider | Create the account's GitHub OIDC identity provider. An account can have only one per URL, so set false and pass oidc\_provider\_arn if it already exists. | `bool` | `true` | no |
| environments | GitHub deployment environments whose jobs may assume the role. An environment with required reviewers is the strongest gate GitHub offers. | `list(string)` | `[]` | no |
| inline\_policy\_json | Optional inline policy document (JSON) for the role. Statements whose Action is "*" are rejected. | `string` | `null` | no |
| max\_session\_duration | Maximum session length in seconds. One hour covers almost every deploy job. | `number` | `3600` | no |
| oidc\_provider\_arn | ARN of an existing token.actions.githubusercontent.com identity provider. Used only when create\_oidc\_provider is false. | `string` | `null` | no |
| permissions\_boundary\_arn | Optional permissions boundary for the role. | `string` | `null` | no |
| policy\_arns | Managed policy ARNs to attach to the role. AdministratorAccess and PowerUserAccess are rejected; grant what the pipeline deploys, not everything. | `list(string)` | `[]` | no |
| tags | Extra tags for every resource. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| oidc\_provider\_arn | ARN of the GitHub OIDC identity provider the role trusts. |
| role\_arn | ARN to put in the workflow's aws-actions/configure-aws-credentials role-to-assume. |
| role\_name | Name of the role. |
| trusted\_subjects | The exact token subjects allowed to assume the role. |
<!-- END_TF_DOCS -->
