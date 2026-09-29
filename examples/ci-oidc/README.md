# ci-oidc

A GitHub Actions deploy with no stored AWS keys. The role this example creates
can be assumed only by workflow runs on the `main` branch of one repository,
and can only ship new code to one Lambda function.

**What this costs:** $0. IAM roles and OIDC providers are free.

## Run it

```sh
terraform init
terraform apply -var github_repository=your-org/your-repo
terraform output role_arn
```

Then copy [`deploy-workflow.yml.example`](deploy-workflow.yml.example) to
`.github/workflows/deploy.yml` in that repository and put the `role_arn` output
in `role-to-assume`. The ARN is not a secret; the trust policy is what protects it.

If the account already has a GitHub OIDC provider (an account can have only
one), apply with `-var create_oidc_provider=false -var oidc_provider_arn=<arn>`.

## What the role can do

```
Trusted:  repo:your-org/your-repo:ref:refs/heads/main   (exact match, audience sts.amazonaws.com)
Allowed:  lambda:UpdateFunctionCode, lambda:GetFunction on function:go-serverless-hello
```

A pull request, another branch, a fork or another repository cannot assume it.

## Inputs

| Name | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region of the function. |
| `run_id` | `example` | Tag value for everything created. |
| `github_repository` | `your-org/your-repo` | The repository allowed to deploy. |
| `function_name` | `go-serverless-hello` | The function it may update. |
| `create_oidc_provider` | `true` | Create the account's GitHub OIDC provider. |
| `oidc_provider_arn` | `null` | Existing provider, when not creating one. |
