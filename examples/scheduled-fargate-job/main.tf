provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "terraform-aws-go-serverless"
      run_id  = var.run_id
      example = "scheduled-fargate-job"
    }
  }
}

# The account's default VPC: public subnets, an internet gateway, no NAT.
# That is exactly what a no-NAT Fargate task needs, and it costs nothing.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

module "job" {
  source = "../../modules/fargate-task"

  name       = var.name
  run_id     = var.run_id
  image_tag  = var.image_tag
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  schedule_expression = var.schedule_expression

  environment_variables = { RUN_ID = var.run_id }

  # Examples should tear down cleanly even after an image was pushed.
  force_delete_repository = true
}
