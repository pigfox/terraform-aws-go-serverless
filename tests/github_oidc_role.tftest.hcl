# modules/github-oidc-role — plan-only, mocked provider, no AWS account touched.
# See go_lambda.tftest.hcl for why the mock block is repeated per file.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock-role" }
  }
}

variables {
  role_name         = "deploy"
  run_id            = "test-run"
  github_repository = "example-org/example-repo"
}

run "trust_is_one_repo_one_branch" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == ["repo:example-org/example-repo:ref:refs/heads/main"]
    error_message = "by default only the main branch of the one repository may assume the role"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "the audience must be pinned to sts.amazonaws.com"
  }

  assert {
    condition     = !can(jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringLike)
    error_message = "the trust policy must not use pattern matching"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] :
      !strcontains(s, "*")
    ])
    error_message = "no trusted subject may contain a wildcard"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "the role must trust only the GitHub OIDC provider"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    error_message = "the role must be assumable only by web identity"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1 && aws_iam_openid_connect_provider.github[0].client_id_list == toset(["sts.amazonaws.com"])
    error_message = "the provider must be created with the STS audience"
  }

  assert {
    condition     = aws_iam_role.this.max_session_duration == 3600
    error_message = "sessions must default to one hour"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0 && length(aws_iam_role_policy.inline) == 0
    error_message = "the role must start with no permissions"
  }

  assert {
    condition     = aws_iam_role.this.tags["run_id"] == "test-run" && aws_iam_openid_connect_provider.github[0].tags["project"] == "terraform-aws-go-serverless"
    error_message = "role and provider must carry the project and run_id tags"
  }
}

run "environments_prs_and_existing_provider" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    branches             = []
    environments         = ["production"]
    allow_pull_requests  = true
    create_oidc_provider = false
    oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    policy_arns          = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  }

  assert {
    condition = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == [
      "repo:example-org/example-repo:environment:production",
      "repo:example-org/example-repo:pull_request",
    ]
    error_message = "environment and pull_request subjects must be exact"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "no provider must be created when an existing one is given"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 1
    error_message = "given policies must be attached"
  }
}

run "rejects_wildcard_repository" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    github_repository = "example-org/*"
  }

  expect_failures = [var.github_repository]
}

run "rejects_wildcard_branch" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    branches = ["release/*"]
  }

  expect_failures = [var.branches]
}

run "rejects_administrator_access" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  }

  expect_failures = [var.policy_arns]
}

run "rejects_star_inline_policy" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    inline_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
  }

  expect_failures = [var.inline_policy_json]
}

run "rejects_no_subjects" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    branches = []
  }

  expect_failures = [aws_iam_role.this]
}

run "rejects_missing_provider_arn" {
  command = plan

  module {
    source = "./modules/github-oidc-role"
  }

  variables {
    create_oidc_provider = false
  }

  expect_failures = [aws_iam_role.this]
}
