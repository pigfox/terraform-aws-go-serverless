data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  tags = merge(var.tags, {
    project = "terraform-aws-go-serverless"
    run_id  = var.run_id
  })

  # ARNs built from known parts so every policy is readable in the plan.
  arn_prefix         = "arn:${data.aws_partition.current.partition}"
  region             = data.aws_region.current.region
  account            = data.aws_caller_identity.current.account_id
  repository_arn     = "${local.arn_prefix}:ecr:${local.region}:${local.account}:repository/${var.name}"
  log_group_arn      = "${local.arn_prefix}:logs:${local.region}:${local.account}:log-group:/ecs/${var.name}"
  task_family_arn    = "${local.arn_prefix}:ecs:${local.region}:${local.account}:task-definition/${var.name}:*"
  cluster_arn        = "${local.arn_prefix}:ecs:${local.region}:${local.account}:cluster/${var.name}"
  execution_role_arn = "${local.arn_prefix}:iam::${local.account}:role/${var.name}-exec"
  task_role_arn      = "${local.arn_prefix}:iam::${local.account}:role/${var.name}-task"

  scheduled = var.schedule_expression != null

  execution_statements = concat(
    [
      {
        # ecr:GetAuthorizationToken has no resource-level permissions in IAM;
        # "*" is the only value AWS accepts for it. Every other statement is
        # scoped to one ARN.
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid      = "PullOwnImage"
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
        Resource = [local.repository_arn]
      },
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["${local.log_group_arn}:*"]
      },
    ],
    length(var.secrets) == 0 ? [] : [{
      Sid      = "ReadNamedSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = distinct(values(var.secrets))
    }],
  )
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete_repository

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the newest ${var.ecr_keep_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_keep_images
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  # Container Insights is billed per metric; off by default for cost.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_iam_role" "execution" {
  name = "${var.name}-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account } }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "execution" {
  name = "${var.name}-exec"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.execution_statements
  })
}

# The role the job's own code runs as. It has no permissions: attach what the
# job needs to the task_role_name output.
resource "aws_iam_role" "task" {
  name = "${var.name}-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account } }
    }]
  })
  tags = local.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-task"
  description = "Egress-only security group for the ${var.name} Fargate task. No inbound rules."
  vpc_id      = var.vpc_id
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "https" {
  count = var.allow_all_egress ? 0 : 1

  security_group_id = aws_security_group.this.id
  description       = "HTTPS out, for ECR, CloudWatch Logs and APIs"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.allow_all_egress ? 1 : 0

  security_group_id = aws_security_group.this.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.architecture
  }

  container_definitions = jsonencode([{
    name      = var.name
    image     = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
    essential = true
    command   = var.command

    environment = [for k in sort(keys(var.environment_variables)) : { name = k, value = var.environment_variables[k] }]
    secrets     = [for k in sort(keys(var.secrets)) : { name = k, valueFrom = var.secrets[k] }]

    readonlyRootFilesystem = true

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = local.region
        awslogs-stream-prefix = var.name
      }
    }
  }])

  tags = local.tags
}

resource "aws_scheduler_schedule_group" "this" {
  count = local.scheduled ? 1 : 0

  name = var.name
  tags = local.tags
}

resource "aws_iam_role" "scheduler" {
  count = local.scheduled ? 1 : 0

  name = "${var.name}-scheduler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account } }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "scheduler" {
  count = local.scheduled ? 1 : 0

  name = "${var.name}-scheduler"
  role = aws_iam_role.scheduler[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RunThisTaskOnThisCluster"
        Effect    = "Allow"
        Action    = ["ecs:RunTask"]
        Resource  = [local.task_family_arn]
        Condition = { ArnEquals = { "ecs:cluster" = local.cluster_arn } }
      },
      {
        Sid      = "TagTheTaskItStarts"
        Effect   = "Allow"
        Action   = ["ecs:TagResource"]
        Resource = ["${local.arn_prefix}:ecs:${local.region}:${local.account}:task/${var.name}/*"]
        Condition = {
          StringEquals = { "ecs:CreateAction" = "RunTask" }
        }
      },
      {
        Sid      = "PassOnlyThisTasksRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [local.execution_role_arn, local.task_role_arn]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      },
    ]
  })
}

resource "aws_scheduler_schedule" "this" {
  count = local.scheduled ? 1 : 0

  name                         = var.name
  group_name                   = aws_scheduler_schedule_group.this[0].name
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.this.arn
    role_arn = aws_iam_role.scheduler[0].arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.this.arn
      launch_type         = "FARGATE"
      task_count          = 1
      propagate_tags      = "TASK_DEFINITION"

      network_configuration {
        subnets          = var.subnet_ids
        security_groups  = [aws_security_group.this.id]
        assign_public_ip = var.assign_public_ip
      }
    }

    # A failed start is not retried into a pile of overlapping runs.
    retry_policy {
      maximum_retry_attempts = 0
    }
  }
}
