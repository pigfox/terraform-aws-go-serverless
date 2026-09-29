# fargate-task

A container job on Fargate that runs on a schedule or on demand and then
exits. No load balancer, no NAT gateway, no EC2. The module creates the ECR
repository, an ECS cluster, the task definition, a log group, an egress-only
security group, the IAM roles, and (when `schedule_expression` is set) an
EventBridge Scheduler schedule.

```hcl
module "job" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/fargate-task"

  name       = "nightly-report"
  run_id     = "prod"
  image_tag  = "v3"
  vpc_id     = "vpc-0123abcd"
  subnet_ids = ["subnet-0123abcd", "subnet-4567efgh"] # public subnets

  schedule_expression = "cron(0 3 * * ? *)" # 03:00 UTC daily; null = run-once
}
```

Leave `schedule_expression` null for a run-once task and start it with the
command in the `run_task_command` output.

## How it works without a NAT gateway

A NAT gateway costs about $33 a month before it moves a byte. Instead the task
runs in a **public** subnet with a public IP, so it reaches ECR and CloudWatch
Logs directly over the internet gateway. The security group has no inbound
rules at all, so a public IP does not mean a reachable task. Outbound is
limited to TCP 443 unless `allow_all_egress` is set.

## What it costs

Nothing while no task is running (ECS clusters and task definitions are free).
A run of the default size (0.25 vCPU, 0.5 GB, ARM64) costs about $0.00082 per five
minutes, so a five-minute nightly job is about $0.025 a month. Add the public IPv4
address at $0.005 per hour while the task runs, ECR storage at $0.10 per GB-month
(a scratch-based Go image is a few MB), and CloudWatch Logs at $0.50 per GB. The
scheduler's free tier covers 14 million invocations a month. (us-east-1 list
prices, 2026.)

## Security defaults

- No inbound rules; egress limited to HTTPS by default.
- ECR tags are immutable and images are scanned on push; old images expire.
- The execution role can pull from this repository, write to this log group and
  read exactly the secrets in `secrets`. Its one `"*"` resource is
  `ecr:GetAuthorizationToken`, which AWS does not allow to be scoped.
- The task role (what your code runs as) starts with **no** permissions; attach
  what the job needs to `task_role_name`.
- The scheduler role can run only this task family on this cluster and pass only
  this task's two roles.
- Container Insights is off (it is billed per metric); turn it on if you need it.

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
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_scheduler_schedule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_scheduler_schedule_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| image\_tag | Tag of the image in the module's ECR repository to run. Tags are immutable, so a new build means a new tag and a new task definition revision. | `string` | n/a | yes |
| name | Name for the task family, ECR repository, cluster, log group (/ecs/<name>) and IAM roles. | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| subnet\_ids | Subnets the task may be placed in. With no NAT gateway these must be public subnets and assign\_public\_ip must stay true, or the task cannot pull its image. | `list(string)` | n/a | yes |
| vpc\_id | VPC the task's security group is created in. | `string` | n/a | yes |
| allow\_all\_egress | Allow outbound traffic on every port. false (the default) allows only TCP 443, which is enough for ECR, CloudWatch Logs and HTTPS APIs. | `bool` | `false` | no |
| architecture | CPU architecture of the image. ARM64 (Graviton) is about 20% cheaper per vCPU-hour on Fargate. | `string` | `"ARM64"` | no |
| assign\_public\_ip | Give the task a public IP. Required in a public subnet without a NAT gateway (the default design here); set false only if you provide NAT or VPC endpoints yourself. | `bool` | `true` | no |
| command | Override the image's CMD. null keeps the image default. | `list(string)` | `null` | no |
| cpu | Task CPU units (256 = 0.25 vCPU). | `number` | `256` | no |
| ecr\_keep\_images | How many images the repository keeps; older ones are expired so storage does not grow forever. | `number` | `10` | no |
| environment\_variables | Plain environment variables for the container. Do not put secrets here; use secrets. | `map(string)` | `{}` | no |
| force\_delete\_repository | Let terraform destroy delete the ECR repository while it still holds images. | `bool` | `false` | no |
| log\_retention\_days | How long CloudWatch keeps the task's logs. Cannot be 0 (never expire). | `number` | `14` | no |
| memory | Task memory in MiB. Must be a combination Fargate accepts for the chosen cpu. | `number` | `512` | no |
| schedule\_expression | EventBridge Scheduler expression, such as "rate(1 day)" or "cron(0 3 * * ? *)". null creates no schedule: the task is run-once, started with the run\_task\_command output. | `string` | `null` | no |
| schedule\_timezone | IANA time zone the cron expression is evaluated in. | `string` | `"UTC"` | no |
| secrets | Environment variable name to Secrets Manager secret ARN. ECS injects the value at start; the execution role may read exactly these ARNs. | `map(string)` | `{}` | no |
| tags | Extra tags for every resource. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster\_name | Name of the ECS cluster the task runs on. |
| log\_group\_name | CloudWatch log group the task writes to. |
| repository\_url | ECR repository URL to push the image to (docker push <repository\_url>:<image\_tag>). |
| run\_task\_command | AWS CLI command that starts the task once, by hand. |
| schedule\_name | Name of the EventBridge Scheduler schedule, or null for a run-once task. |
| security\_group\_id | ID of the task's egress-only security group. |
| task\_definition\_arn | ARN of the current task definition revision. |
| task\_role\_name | Name of the role the job's code runs as. It starts with no permissions; attach what the job needs. |
<!-- END_TF_DOCS -->
