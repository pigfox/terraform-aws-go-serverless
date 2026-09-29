# modules/dynamodb-table — plan-only, mocked provider, no AWS account touched.
# See go_lambda.tftest.hcl for why the mock block is repeated per file.
mock_provider "aws" {}

variables {
  name   = "items"
  run_id = "test-run"
}

run "defaults" {
  command = plan

  module {
    source = "./modules/dynamodb-table"
  }

  assert {
    condition     = aws_dynamodb_table.this.billing_mode == "PAY_PER_REQUEST"
    error_message = "table must be on-demand so an idle table costs nothing"
  }

  assert {
    condition     = aws_dynamodb_table.this.hash_key == "pk" && aws_dynamodb_table.this.range_key == null
    error_message = "default key must be a string partition key named pk, no sort key"
  }

  assert {
    condition     = length(aws_dynamodb_table.this.attribute) == 1
    error_message = "only key attributes may be declared"
  }

  assert {
    condition     = aws_dynamodb_table.this.point_in_time_recovery[0].enabled == true
    error_message = "point-in-time recovery must default on"
  }

  assert {
    # enabled = false selects the AWS-owned key. kms_key_arn is not asserted:
    # the provider marks it computed, so it is unknown at plan when unset.
    condition     = aws_dynamodb_table.this.server_side_encryption[0].enabled == false
    error_message = "default encryption must use the free AWS-owned key, not a customer KMS key"
  }

  assert {
    condition     = length(aws_dynamodb_table.this.ttl) == 0
    error_message = "no TTL unless an attribute is named"
  }

  assert {
    condition     = aws_dynamodb_table.this.deletion_protection_enabled == false
    error_message = "deletion protection must default off so examples tear down"
  }

  assert {
    condition     = aws_dynamodb_table.this.tags["project"] == "terraform-aws-go-serverless" && aws_dynamodb_table.this.tags["run_id"] == "test-run"
    error_message = "table must carry the project and run_id tags"
  }

  assert {
    condition     = alltrue([for a in output.crud_actions : !strcontains(a, "*") && a != "dynamodb:Scan" && a != "dynamodb:DeleteTable"])
    error_message = "crud_actions must be explicit item-level actions only"
  }
}

run "sort_key_ttl_and_production_settings" {
  command = plan

  module {
    source = "./modules/dynamodb-table"
  }

  variables {
    range_key              = "sk"
    range_key_type         = "N"
    ttl_attribute          = "expires_at"
    deletion_protection    = true
    point_in_time_recovery = false
    kms_key_arn            = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = aws_dynamodb_table.this.range_key == "sk" && length(aws_dynamodb_table.this.attribute) == 2
    error_message = "sort key must be declared as a second attribute"
  }

  assert {
    condition     = aws_dynamodb_table.this.ttl[0].attribute_name == "expires_at" && aws_dynamodb_table.this.ttl[0].enabled
    error_message = "TTL must be enabled on the named attribute"
  }

  assert {
    condition     = aws_dynamodb_table.this.deletion_protection_enabled && !aws_dynamodb_table.this.point_in_time_recovery[0].enabled
    error_message = "toggles must be honoured"
  }

  assert {
    condition     = aws_dynamodb_table.this.server_side_encryption[0].enabled && aws_dynamodb_table.this.server_side_encryption[0].kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    error_message = "a given KMS key must be used"
  }
}

run "rejects_bad_key_type" {
  command = plan

  module {
    source = "./modules/dynamodb-table"
  }

  variables {
    hash_key_type = "STRING"
  }

  expect_failures = [var.hash_key_type]
}

run "rejects_bad_kms_arn" {
  command = plan

  module {
    source = "./modules/dynamodb-table"
  }

  variables {
    kms_key_arn = "alias/my-key"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_short_name" {
  command = plan

  module {
    source = "./modules/dynamodb-table"
  }

  variables {
    name = "ab"
  }

  expect_failures = [var.name]
}
