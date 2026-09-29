# environments

Two environments, `dev/` and `prod/`, built from the same modules with
different inputs, each keeping state in S3 under its own key.

**What this costs:** $0 idle for both environments, plus a few cents a month for
the state bucket. Prod adds a budget alarm, which is free.

## Layout

```
state-bucket/   apply once with local state: the bucket both environments use
dev/            root module, small limits, 3-day logs, no deletion protection
prod/           root module, larger limits, 30-day logs, protected table, budget alarm
```

| Input | dev | prod |
|---|---|---|
| `memory_size` | 128 | 256 |
| `reserved_concurrency` | 2 | 20 |
| `throttling_rate_limit` / burst | 5 / 10 | 50 / 100 |
| `log_retention_days` | 3 | 30 |
| `table_deletion_protection` | false | true |
| budget alarm | no | yes, $10/month |

## State locking without DynamoDB

Both `backend.tf` files set `use_lockfile = true`. Terraform (1.10+) and OpenTofu
(1.10+) then lock by writing `<key>.tflock` next to the state with an S3
conditional write, so there is no DynamoDB lock table to create or pay for.

## Run it

```sh
cd state-bucket
terraform init && terraform apply -var bucket_name=<globally-unique-name>
cd ..
# put that bucket name in dev/backend.tf and prod/backend.tf
../serverless-api/build.sh
cd dev  && terraform init && terraform apply
cd ../prod && terraform init && terraform apply -var 'alert_emails=["you@example.com"]'
```

Destroying prod needs `table_deletion_protection = false` applied first; that
is the point of it.
