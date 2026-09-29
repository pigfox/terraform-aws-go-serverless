locals {
  tags = merge(var.tags, {
    project = "terraform-aws-go-serverless"
    run_id  = var.run_id
  })

  attributes = concat(
    [{ name = var.hash_key, type = var.hash_key_type }],
    var.range_key == null ? [] : [{ name = var.range_key, type = var.range_key_type }],
  )
}

resource "aws_dynamodb_table" "this" {
  name         = var.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key
  range_key    = var.range_key

  deletion_protection_enabled = var.deletion_protection

  dynamic "attribute" {
    for_each = local.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    # enabled = false means the AWS-owned key, not "unencrypted": DynamoDB
    # always encrypts at rest. true switches to a KMS key (AWS-managed, or
    # the customer key when one is given).
    enabled     = var.kms_key_arn != null
    kms_key_arn = var.kms_key_arn
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute == null ? [] : [var.ttl_attribute]
    content {
      attribute_name = ttl.value
      enabled        = true
    }
  }

  tags = local.tags
}
