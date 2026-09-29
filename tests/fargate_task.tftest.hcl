# modules/fargate-task — mocked provider, no AWS account touched.
# See go_lambda.tftest.hcl for why the mock block is repeated per file, and
# http_api.tftest.hcl for why the one run over computed wiring is a mock apply.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock-role" }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:cluster/nightly" }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = { arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/nightly:1" }
  }
  mock_resource "aws_ecr_repository" {
    defaults = { repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/nightly" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0" }
  }
}

variables {
  name       = "nightly"
  run_id     = "test-run"
  image_tag  = "v1"
  vpc_id     = "vpc-0123abcd"
  subnet_ids = ["subnet-0123abcd"]
}

run "run_once_defaults" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  assert {
    condition     = length(aws_scheduler_schedule.this) == 0 && length(aws_iam_role.scheduler) == 0
    error_message = "no schedule_expression must mean no schedule and no scheduler role"
  }

  assert {
    condition     = aws_ecs_task_definition.this.requires_compatibilities == toset(["FARGATE"]) && aws_ecs_task_definition.this.network_mode == "awsvpc"
    error_message = "must be a Fargate task, never EC2"
  }

  assert {
    condition     = aws_ecs_task_definition.this.runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "default architecture must be ARM64"
  }

  assert {
    condition     = aws_ecs_task_definition.this.cpu == "256" && aws_ecs_task_definition.this.memory == "512"
    error_message = "default size must be the smallest Fargate size"
  }

  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push
    error_message = "ECR tags must be immutable and images scanned on push"
  }

  assert {
    condition     = one([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"]) == "disabled"
    error_message = "Container Insights (billed) must default off"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 14
    error_message = "logs must expire"
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.https) == 1 && length(aws_vpc_security_group_egress_rule.all) == 0
    error_message = "egress must default to HTTPS only"
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.https[0].from_port == 443 && aws_vpc_security_group_egress_rule.https[0].to_port == 443
    error_message = "the default egress rule must be port 443 only"
  }

  assert {
    condition     = aws_ecs_cluster.this.tags["run_id"] == "test-run" && aws_ecr_repository.this.tags["project"] == "terraform-aws-go-serverless"
    error_message = "cluster and repository must carry the project and run_id tags"
  }

}

run "execution_role_is_least_privilege" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.execution.policy).Statement : [for a in s.Action : !strcontains(a, "*")]
    ]))
    error_message = "no execution-role action may contain a wildcard"
  }

  assert {
    # GetAuthorizationToken is the one action AWS only accepts on "*".
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.execution.policy).Statement :
      s.Action == ["ecr:GetAuthorizationToken"] if contains(s.Resource, "*")
    ])
    error_message = "the only statement allowed a \"*\" resource is ecr:GetAuthorizationToken"
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.execution.policy).Statement : s.Resource if s.Sid == "PullOwnImage"]) == ["arn:aws:ecr:us-east-1:123456789012:repository/nightly"]
    error_message = "image pull must be scoped to the module's own repository"
  }

  assert {
    condition     = length([for s in jsondecode(aws_iam_role_policy.execution.policy).Statement : s if s.Sid == "ReadNamedSecrets"]) == 0
    error_message = "no secret access without secrets"
  }
}

run "scheduled_with_secrets" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  variables {
    schedule_expression = "cron(0 3 * * ? *)"
    secrets             = { DB_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:job/db-AbCdEf" }
  }

  assert {
    condition     = aws_scheduler_schedule.this[0].schedule_expression == "cron(0 3 * * ? *)" && aws_scheduler_schedule.this[0].schedule_expression_timezone == "UTC"
    error_message = "schedule must use the given expression in UTC"
  }

  assert {
    condition     = aws_scheduler_schedule.this[0].target[0].retry_policy[0].maximum_retry_attempts == 0
    error_message = "failed starts must not be retried into overlapping runs"
  }

  assert {
    condition     = aws_scheduler_schedule_group.this[0].tags["run_id"] == "test-run"
    error_message = "the schedule group must carry the run_id tag"
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.scheduler[0].policy).Statement : s.Resource if s.Sid == "PassOnlyThisTasksRoles"]) == ["arn:aws:iam::123456789012:role/nightly-exec", "arn:aws:iam::123456789012:role/nightly-task"]
    error_message = "the scheduler may pass only this task's two roles"
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.scheduler[0].policy).Statement : s.Resource if s.Sid == "RunThisTaskOnThisCluster"]) == ["arn:aws:ecs:us-east-1:123456789012:task-definition/nightly:*"]
    error_message = "the scheduler may run only this task family"
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_role_policy.execution.policy).Statement : s.Resource if s.Sid == "ReadNamedSecrets"]) == ["arn:aws:secretsmanager:us-east-1:123456789012:secret:job/db-AbCdEf"]
    error_message = "the execution role may read exactly the named secrets"
  }
}

run "wiring" {
  # Mock apply: the image URI and target ARNs are computed.
  command = apply

  module {
    source = "./modules/fargate-task"
  }

  variables {
    schedule_expression = "rate(1 day)"
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].image == "123456789012.dkr.ecr.us-east-1.amazonaws.com/nightly:v1"
    error_message = "the container must run the module's repository at the given tag"
  }

  assert {
    condition     = aws_scheduler_schedule.this[0].target[0].arn == "arn:aws:ecs:us-east-1:123456789012:cluster/nightly"
    error_message = "the schedule must target the module's cluster"
  }

  assert {
    condition     = aws_scheduler_schedule.this[0].target[0].ecs_parameters[0].network_configuration[0].assign_public_ip == true
    error_message = "scheduled runs must get a public IP by default (no NAT)"
  }

  assert {
    condition     = strcontains(output.run_task_command, "assignPublicIp=ENABLED") && strcontains(output.run_task_command, "subnets=[subnet-0123abcd]") && strcontains(output.run_task_command, "securityGroups=[sg-0123456789abcdef0]")
    error_message = "run_task_command must reflect the network settings"
  }
}

run "rejects_uppercase_name" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  variables {
    name = "Nightly"
  }

  expect_failures = [var.name]
}

run "rejects_bad_schedule" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  variables {
    schedule_expression = "every day"
  }

  expect_failures = [var.schedule_expression]
}

run "rejects_empty_subnets" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  variables {
    subnet_ids = []
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_bad_cpu" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  variables {
    cpu = 128
  }

  expect_failures = [var.cpu]
}

run "rejects_wildcard_secret" {
  command = plan

  module {
    source = "./modules/fargate-task"
  }

  variables {
    secrets = { ALL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:*" }
  }

  expect_failures = [var.secrets]
}
