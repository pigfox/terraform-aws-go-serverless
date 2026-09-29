terraform {
  # State lives in the bucket from ../state-bucket. use_lockfile takes the lock
  # with an S3 conditional write of <key>.tflock next to the state, so there is
  # no DynamoDB lock table to create or pay for.
  backend "s3" {
    bucket       = "change-me-tf-state-go-serverless"
    key          = "go-serverless/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
