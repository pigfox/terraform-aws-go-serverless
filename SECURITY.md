# Security policy

## Reporting a vulnerability

Please report security problems privately through GitHub's
[private vulnerability reporting](https://github.com/pigfox/terraform-aws-go-serverless/security/advisories/new)
for this repository. Do not open a public issue.

Include what you found, which module and inputs are affected, and how to
reproduce it (a `terraform plan` is ideal). You should get an acknowledgement
within a week.

## Scope

In scope: a module default or input combination that grants more access than
documented, exposes data publicly, leaks a secret into state or logs, or creates
unexpectedly billable resources.

Out of scope: problems in AWS itself, in the Terraform or OpenTofu binaries, or
in the AWS provider. Please report those upstream.

## Supported versions

The project is pre-release. Fixes land on `main`; there are no release
branches yet.

## What this repository never contains

No credentials, no Terraform state, no `.tfvars` and no `.env` files. CI holds
no AWS credentials and runs a secret scan on every change, and
`scripts/hygiene.sh` fails the build if any such file is tracked.
