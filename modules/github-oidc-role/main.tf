data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  tags = merge(var.tags, {
    project = "terraform-aws-go-serverless"
    run_id  = var.run_id
  })

  issuer = "token.actions.githubusercontent.com"

  # Built from known parts when the module creates the provider, so the trust
  # policy is fully readable in the plan.
  provider_arn = var.create_oidc_provider ? "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.issuer}" : var.oidc_provider_arn

  subjects = concat(
    [for b in var.branches : "repo:${var.github_repository}:ref:refs/heads/${b}"],
    [for e in var.environments : "repo:${var.github_repository}:environment:${e}"],
    var.allow_pull_requests ? ["repo:${var.github_repository}:pull_request"] : [],
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.issuer}"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        # StringEquals, not StringLike: every subject is an exact string, so
        # there is no pattern to widen by accident.
        StringEquals = {
          "${local.issuer}:aud" = "sts.amazonaws.com"
          "${local.issuer}:sub" = local.subjects
        }
      }
    }]
  })

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.create_oidc_provider || var.oidc_provider_arn != null
      error_message = "set oidc_provider_arn when create_oidc_provider is false."
    }
    precondition {
      condition     = length(local.subjects) > 0
      error_message = "at least one branch, environment or pull_request trust must be given."
    }
  }

  depends_on = [aws_iam_openid_connect_provider.github]
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  name   = "${var.role_name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}
