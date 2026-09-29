terraform {
  # Same bucket as dev, different key: the two environments never share state
  # or a lock. See dev/backend.tf for how use_lockfile locks without DynamoDB.
  backend "s3" {
    bucket       = "change-me-tf-state-go-serverless"
    key          = "go-serverless/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
