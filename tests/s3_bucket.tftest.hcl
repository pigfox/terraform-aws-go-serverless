# modules/s3-bucket — plan-only, mocked provider, no AWS account touched.
# See go_lambda.tftest.hcl for why the mock block is repeated per file.
mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  name   = "example-bucket-123"
  run_id = "test-run"
}

run "defaults_are_private" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "all four public access blocks must be on"
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled (BucketOwnerEnforced)"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "default encryption must be SSE-S3, not a customer KMS key"
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default off"
  }

  assert {
    condition     = aws_s3_bucket.this.tags["project"] == "terraform-aws-go-serverless" && aws_s3_bucket.this.tags["run_id"] == "test-run"
    error_message = "bucket must carry the project and run_id tags"
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 0
    error_message = "access logging must be opt-in"
  }
}

run "policy_denies_plain_http" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement[0].Effect == "Deny"
    error_message = "the only bucket policy statement must be a Deny"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "the Deny must apply to requests without TLS"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement[0].Resource == ["arn:aws:s3:::example-bucket-123", "arn:aws:s3:::example-bucket-123/*"]
    error_message = "the Deny must cover the bucket and every object in it"
  }

  assert {
    condition     = length([for s in jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement : s if s.Effect == "Allow"]) == 0
    error_message = "the module must never grant anything through the bucket policy"
  }
}

run "versioning_and_lifecycle" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  variables {
    lifecycle_rules = [{ id = "tmp", prefix = "tmp/", expiration_days = 1 }]
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must default on"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].noncurrent_version_expiration[0].noncurrent_days == 30
    error_message = "old versions must expire after 30 days by default"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    error_message = "incomplete multipart uploads must be aborted after 7 days"
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this.rule) == 2 && aws_s3_bucket_lifecycle_configuration.this.rule[1].expiration[0].days == 1
    error_message = "extra lifecycle rules must be appended"
  }
}

run "versioning_off" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  variables {
    versioning = false
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"
    error_message = "versioning toggle must be honoured"
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this.rule[0].noncurrent_version_expiration) == 0
    error_message = "no noncurrent-version rule without versioning"
  }
}

run "customer_key_when_given" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "a given KMS key must switch to SSE-KMS"
  }
}

run "rejects_bad_bucket_name" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  variables {
    name = "Not_A_Bucket"
  }

  expect_failures = [var.name]
}

run "rejects_reserved_rule_id" {
  command = plan

  module {
    source = "./modules/s3-bucket"
  }

  variables {
    lifecycle_rules = [{ id = "baseline", prefix = "x/", expiration_days = 1 }]
  }

  expect_failures = [var.lifecycle_rules]
}
