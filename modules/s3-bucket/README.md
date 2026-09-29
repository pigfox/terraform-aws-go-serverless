# s3-bucket

A private S3 bucket: all four public-access blocks on, ACLs disabled,
encryption at rest, a policy that refuses any request not made over TLS,
versioning with old versions expiring, and a lifecycle rule that clears
abandoned multipart uploads.

```hcl
module "bucket" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/s3-bucket"

  name   = "example-org-orders-exports"
  run_id = "prod"

  lifecycle_rules = [{ id = "tmp", prefix = "tmp/", expiration_days = 1 }]
}
```

## What it costs

Nothing for an empty bucket. $0.023 per GB-month in S3 Standard plus fractions of a
cent per thousand requests. Versioning stores every overwritten version, which is
why they expire after 30 days by default. SSE-S3 encryption is free; SSE-KMS with
a customer key adds about $1/month plus request charges. (us-east-1 list prices, 2026.)

## Security defaults

- Public access is blocked and **not configurable**. A public bucket is a
  different module.
- `BucketOwnerEnforced`: ACLs are disabled; access is controlled by IAM alone.
- The bucket policy contains exactly one statement, a Deny for requests without
  TLS. The module never grants access through the bucket policy.
- `force_destroy` is off: `terraform destroy` will not delete a bucket that still
  holds data.
- Access logging is available (`access_log_bucket`) but off, since it needs a
  second bucket.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.tls_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Bucket name. Must be globally unique across all AWS accounts. | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| abort\_incomplete\_multipart\_days | Days after which unfinished multipart uploads are discarded. Their parts are billed but invisible in the console. | `number` | `7` | no |
| access\_log\_bucket | Name of an existing bucket to receive server access logs. null (the default) disables access logging. | `string` | `null` | no |
| force\_destroy | Let terraform destroy delete a bucket that still holds objects. Off by default: a data bucket should not vanish with its contents by accident. | `bool` | `false` | no |
| kms\_key\_arn | Customer-managed KMS key for SSE-KMS. null (the default) uses SSE-S3 (AES-256), which is free. | `string` | `null` | no |
| lifecycle\_rules | Additional expiration rules, each for a key prefix. Example: { id = "tmp", prefix = "tmp/", expiration\_days = 1 }. | ```list(object({ id = string prefix = string expiration_days = number }))``` | `[]` | no |
| noncurrent\_version\_expiration\_days | Days after which a superseded object version is deleted. Only applies when versioning is on. | `number` | `30` | no |
| tags | Extra tags for every resource. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |
| versioning | Keep previous versions of overwritten or deleted objects. On by default; old versions expire after noncurrent\_version\_expiration\_days so they do not accumulate cost forever. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_arn | ARN of the bucket, for IAM policies. |
| bucket\_name | Name of the bucket. |
<!-- END_TF_DOCS -->
