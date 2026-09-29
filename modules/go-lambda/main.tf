data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  tags = merge(var.tags, {
    project = "terraform-aws-go-serverless"
    run_id  = var.run_id
  })

  # Built from known parts rather than read back from the log group resource, so
  # the policy is fully known at plan time and a reviewer sees the exact ARN.
  log_group_arn = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}"

  base_statements = [
    {
      Sid      = "WriteOwnLogs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = ["${local.log_group_arn}:*"]
    },
  ]

  secret_statements = length(var.secret_arns) == 0 ? [] : [
    {
      Sid      = "ReadNamedSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.secret_arns
    },
  ]

  extra_statements = [
    for i, s in var.policy_statements : {
      Sid      = "Extra${i}"
      Effect   = "Allow"
      Action   = s.actions
      Resource = s.resources
    }
  ]

  policy = {
    Version   = "2012-10-17"
    Statement = concat(local.base_statements, local.secret_statements, local.extra_statements)
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_iam_role" "this" {
  name = "${var.name}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-lambda"
  role   = aws_iam_role.this.id
  policy = jsonencode(local.policy)
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  role             = aws_iam_role.this.arn
  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path)
  runtime          = "provided.al2023"
  handler          = "bootstrap"
  architectures    = [var.architecture]
  memory_size      = var.memory_size
  timeout          = var.timeout

  reserved_concurrent_executions = var.reserved_concurrency

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) == 0 ? [] : [1]
    content {
      variables = var.environment_variables
    }
  }

  tags = local.tags

  # The role's permissions must exist before the first invocation can log.
  depends_on = [aws_iam_role_policy.this]
}
