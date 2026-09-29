data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # Built from known parts rather than read back from the table so the
  # function's policy is readable in the plan.
  table_arn = "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.name}"

  table_statements = var.create_table ? [{
    actions   = module.table[0].crud_actions
    resources = [local.table_arn, "${local.table_arn}/index/*"]
  }] : []

  environment_variables = merge(
    var.environment_variables,
    var.create_table ? { TABLE_NAME = var.name } : {},
  )
}

module "table" {
  source = "./modules/dynamodb-table"
  count  = var.create_table ? 1 : 0

  name                   = var.name
  run_id                 = var.run_id
  hash_key               = var.table_hash_key
  range_key              = var.table_range_key
  ttl_attribute          = var.table_ttl_attribute
  point_in_time_recovery = var.table_point_in_time_recovery
  deletion_protection    = var.table_deletion_protection
  tags                   = var.tags
}

module "function" {
  source = "./modules/go-lambda"

  name                  = var.name
  run_id                = var.run_id
  zip_path              = var.zip_path
  architecture          = var.architecture
  memory_size           = var.memory_size
  timeout               = var.timeout
  reserved_concurrency  = var.reserved_concurrency
  environment_variables = local.environment_variables
  secret_arns           = var.secret_arns
  policy_statements     = local.table_statements
  log_retention_days    = var.log_retention_days
  tags                  = var.tags
}

module "api" {
  source = "./modules/http-api"

  name                   = var.name
  run_id                 = var.run_id
  lambda_function_name   = module.function.function_name
  lambda_invoke_arn      = module.function.invoke_arn
  routes                 = var.routes
  throttling_rate_limit  = var.throttling_rate_limit
  throttling_burst_limit = var.throttling_burst_limit
  cors_allow_origins     = var.cors_allow_origins
  log_retention_days     = var.log_retention_days
  tags                   = var.tags
}
