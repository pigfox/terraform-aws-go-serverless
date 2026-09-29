# dynamodb-table

An on-demand DynamoDB table: a partition key, an optional sort key, optional
TTL, point-in-time recovery on by default, and encryption with the free
AWS-owned key unless you pass a customer key.

```hcl
module "table" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/dynamodb-table"

  name          = "orders"
  run_id        = "prod"
  range_key     = "sk"
  ttl_attribute = "expires_at"

  deletion_protection = true
}
```

The `crud_actions` output lists the item-level actions a service usually needs
(no `Scan`, no table management), ready to pass to `go-lambda`'s
`policy_statements`.

## What it costs

On-demand billing means nothing for an idle table beyond storage: the first 25 GB
are free, then $0.25 per GB-month. Requests are $0.625 per million writes and
$0.125 per million reads. Point-in-time recovery adds $0.20 per GB-month of table
size, which for a small table is cents. A customer KMS key would add about
$1/month, which is why it is off by default. (us-east-1 list prices, 2026.)

## Security defaults

- Encrypted at rest always (DynamoDB has no unencrypted mode); AWS-owned key by default.
- Point-in-time recovery on.
- Deletion protection is **off** by default so examples and tests tear down. Turn
  it on for anything you would miss.

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
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Table name. | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| deletion\_protection | Refuse DeleteTable until this is turned off. Off by default so examples and tests can be torn down; turn it on for production. | `bool` | `false` | no |
| hash\_key | Partition key attribute name. | `string` | `"pk"` | no |
| hash\_key\_type | Partition key type: S (string), N (number) or B (binary). | `string` | `"S"` | no |
| kms\_key\_arn | Customer-managed KMS key for encryption at rest. null (the default) uses the AWS-owned key, which is free; a customer key costs about $1/month plus requests. | `string` | `null` | no |
| point\_in\_time\_recovery | Continuous backups with 35-day restore. Billed per GB stored, which is cents for a small table; on by default because losing a table is worse. | `bool` | `true` | no |
| range\_key | Optional sort key attribute name. null means a partition key only. | `string` | `null` | no |
| range\_key\_type | Sort key type: S, N or B. Ignored when range\_key is null. | `string` | `"S"` | no |
| tags | Extra tags for every resource. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |
| ttl\_attribute | Attribute holding an epoch-seconds expiry. Items past it are deleted by DynamoDB for free. null disables TTL. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| crud\_actions | The item-level actions a typical service needs on this table, for passing to go-lambda's policy\_statements. Deliberately excludes table management and scans. |
| table\_arn | ARN of the table, for IAM policies. |
| table\_name | Name of the table. |
<!-- END_TF_DOCS -->
