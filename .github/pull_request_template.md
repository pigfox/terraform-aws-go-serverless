## What and why

<!-- What this changes and the reason for it. -->

## Checklist

- [ ] `terraform fmt -recursive` and `./scripts/docs.sh` run, results committed
- [ ] Tests added or updated in `tests/` for every new input or behaviour (default, rejection, security property)
- [ ] Mocked tests pass on Terraform and OpenTofu
- [ ] No new always-on cost (NAT, load balancer, EC2, customer KMS key) and no wildcard IAM action
- [ ] Any new trivy exception is in `.trivyignore.yaml`, scoped to its file, with a reason
- [ ] `CHANGELOG.md` updated under Unreleased
