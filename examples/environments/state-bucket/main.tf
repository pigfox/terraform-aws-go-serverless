# Apply this once, with local state, to create the bucket dev and prod keep
# their state in. It is the one root in the repo that has no remote backend:
# something has to exist before a backend can point at it.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "terraform-aws-go-serverless"
      run_id  = var.run_id
      example = "environments"
    }
  }
}

module "state" {
  source = "../../../modules/s3-bucket"

  name   = var.bucket_name
  run_id = var.run_id

  # State history is worth keeping longer than the module default.
  versioning                         = true
  noncurrent_version_expiration_days = 90
}
