# budget-alarm

An AWS Budgets monthly cost budget that emails when actual spend passes 50%,
80% and 100% of a limit, and when the month's forecast passes 100%. The forecast
alert usually fires days before actual spend does.

```hcl
module "budget" {
  source = "github.com/pigfox/terraform-aws-go-serverless//modules/budget-alarm"

  name              = "monthly"
  run_id            = "prod"
  monthly_limit_usd = 10
  alert_emails      = ["ops@example.com"]
}
```

A budget alerts; it does not stop spending. Pair it with the hard caps elsewhere
in this repo (Lambda reserved concurrency, API throttling) if you need a ceiling.

To count only this project's resources, pass
`cost_filter_tags = { project = "terraform-aws-go-serverless" }` after activating
`project` as a cost allocation tag in the Billing console. Budgets data lags
actual usage by up to a day.

## What it costs

AWS Budgets are free to monitor for the first two budgets in an account; see the
AWS Budgets pricing page beyond that. This module creates one budget and no
budget actions.

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
| [aws_budgets_budget.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| alert\_emails | Addresses that receive the alerts. AWS sends a confirmation email to none of them; they simply start receiving mail. | `list(string)` | n/a | yes |
| monthly\_limit\_usd | Monthly spend, in US dollars, that the alert percentages are measured against. | `number` | n/a | yes |
| name | Budget name, unique in the account. | `string` | n/a | yes |
| run\_id | Identifier stamped on every resource as the run\_id tag, so everything one deployment created can be found (and proven gone) through the tagging API. | `string` | n/a | yes |
| actual\_thresholds | Percentages of the limit at which ACTUAL spend sends an alert. | `list(number)` | ```[ 50, 80, 100 ]``` | no |
| cost\_filter\_tags | Only count spend on resources carrying these tags, e.g. { project = "terraform-aws-go-serverless" }. The tag keys must first be activated as cost allocation tags in the Billing console. Empty (the default) counts the whole account. | `map(string)` | `{}` | no |
| forecast\_alert | Also alert when the month's FORECASTED spend passes 100% of the limit, which usually fires days before actual spend does. | `bool` | `true` | no |
| tags | Extra tags for the budget. project and run\_id are always set by the module and win over any value given here. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| budget\_name | Name of the budget. |
| limit\_amount | The monthly limit as AWS stores it (a decimal string in USD). |
<!-- END_TF_DOCS -->
