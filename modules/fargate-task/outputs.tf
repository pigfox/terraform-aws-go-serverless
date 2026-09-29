output "repository_url" {
  description = "ECR repository URL to push the image to (docker push <repository_url>:<image_tag>)."
  value       = aws_ecr_repository.this.repository_url
}

output "cluster_name" {
  description = "Name of the ECS cluster the task runs on."
  value       = aws_ecs_cluster.this.name
}

output "task_definition_arn" {
  description = "ARN of the current task definition revision."
  value       = aws_ecs_task_definition.this.arn
}

output "task_role_name" {
  description = "Name of the role the job's code runs as. It starts with no permissions; attach what the job needs."
  value       = aws_iam_role.task.name
}

output "security_group_id" {
  description = "ID of the task's egress-only security group."
  value       = aws_security_group.this.id
}

output "log_group_name" {
  description = "CloudWatch log group the task writes to."
  value       = aws_cloudwatch_log_group.this.name
}

output "schedule_name" {
  description = "Name of the EventBridge Scheduler schedule, or null for a run-once task."
  value       = local.scheduled ? aws_scheduler_schedule.this[0].name : null
}

output "run_task_command" {
  description = "AWS CLI command that starts the task once, by hand."
  value = join(" ", [
    "aws ecs run-task",
    "--cluster ${aws_ecs_cluster.this.name}",
    "--task-definition ${aws_ecs_task_definition.this.family}",
    "--launch-type FARGATE",
    "--propagate-tags TASK_DEFINITION",
    "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", var.subnet_ids)}],securityGroups=[${aws_security_group.this.id}],assignPublicIp=${var.assign_public_ip ? "ENABLED" : "DISABLED"}}'",
  ])
}
