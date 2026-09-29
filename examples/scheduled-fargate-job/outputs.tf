output "repository_url" {
  description = "ECR repository to push the job image to."
  value       = module.job.repository_url
}

output "run_task_command" {
  description = "Start the job once, now, without waiting for the schedule."
  value       = module.job.run_task_command
}

output "log_group_name" {
  description = "Where the job's output lands."
  value       = module.job.log_group_name
}
