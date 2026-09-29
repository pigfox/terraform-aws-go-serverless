# Contributing

Thanks for helping. Issues and pull requests are welcome.

## What you need

- Terraform 1.10+ or OpenTofu 1.10+ (CI tests the oldest and newest of both)
- [tflint](https://github.com/terraform-linters/tflint), [trivy](https://github.com/aquasecurity/trivy)
  and [terraform-docs](https://terraform-docs.io/)
- Go 1.26+ and `zip`, for the examples and the Terratest suite
- No AWS account. Nothing below touches AWS.

## Before you open a pull request

```sh
terraform fmt -recursive
./scripts/validate-all.sh               # TF=tofu ./scripts/validate-all.sh for OpenTofu
terraform init -backend=false && terraform test
./scripts/assert-count.sh                # test files match tests/ASSERTIONS
tflint --init && tflint --recursive
trivy config --ignorefile .trivyignore.yaml --exit-code 1 .
./scripts/docs.sh                        # regenerates module READMEs; commit the result
```

CI runs the same commands, plus the OpenTofu legs, the Go checks and
`./scripts/hygiene.sh`.

## Rules the modules follow

A change that breaks one of these needs a very good reason in the pull request.

1. **Cheap by default.** No NAT gateways, load balancers, EC2 instances or
   customer-managed KMS keys unless the caller asks. Every log group expires.
2. **Tagged.** Every taggable resource carries `project` and `run_id`.
3. **Least privilege, visible in the plan.** Policies are written in HCL with
   `jsonencode`, ARNs are built from known parts where possible, and there are no
   wildcard actions. Where AWS offers no resource-level permission, say so in a
   comment next to the `"*"`.
4. **Validated inputs.** Every variable has a description and a type, and gets
   a `validation` block wherever a bad value is possible.
5. **Tests in the same change.** A new module or input comes with
   `tests/<module>.tftest.hcl` runs covering the default, at least one
   rejection, and any security property it adds. Tests use `mock_provider`
   only, must pass on both Terraform and OpenTofu, and use `command = plan`
   unless an assertion needs a computed value. Update the file's line in
   `tests/ASSERTIONS` in the same commit: CI fails if the declared run, assert
   and `expect_failures` counts differ from the file, so a deleted check cannot
   pass unnoticed.
6. **A new trivy exception is a design decision.** Add it to `.trivyignore.yaml`
   scoped to its file, with a `statement` explaining why.

## Commit messages

Short imperative subject, then a body explaining why. Conventional-commit
prefixes (`feat:`, `fix:`, `docs:`) are appreciated.

## Live tests

`test/` holds a Terratest suite that creates real resources. Do not run it
unless you mean to spend (a few cents); see [test/README.md](test/README.md).
