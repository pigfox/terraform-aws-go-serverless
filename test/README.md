# Live tests (Terratest)

These tests create **real, billable AWS resources**. They are skipped unless
`TERRATEST_LIVE=1` is set. The mocked suite in [`../tests`](../tests) is what
runs on every change.

## What `TestServerlessAPI` does

1. Builds `examples/serverless-api` with `build.sh`.
2. Applies it with a random `run_id` (`tt-xxxxxx`) and a matching name.
3. Calls `<api_endpoint>/hello` until it answers 200, then checks the JSON body
   exactly, including that `run_id` is this run's.
4. Destroys everything.
5. Asks the Resource Groups Tagging API for anything still tagged with that
   `run_id`, polling for up to five minutes because the API is eventually
   consistent, and checks the IAM role directly because the tagging API does
   not list IAM roles. Anything left fails the test.

A run costs well under $0.01 and takes a few minutes.

## Running it

```sh
cd test
TERRATEST_LIVE=1 AWS_REGION=us-east-1 go test -v -timeout 30m ./...
TERRATEST_LIVE=1 TERRATEST_TF_BINARY=tofu go test -v -timeout 30m ./...   # OpenTofu
```

Credentials come from the standard AWS SDK chain (environment, profile, SSO).
The caller needs permission to create and delete Lambda, API Gateway,
CloudWatch Logs and IAM roles, and `tag:GetResources`.

## Without the flag

```sh
go test -v ./...
```

`TestServerlessAPI` reports SKIP, and `TestLiveTestsSkipWithoutFlag` passes.
The second test is what makes the skip a checked property rather than a
convention: it fails if the gate ever stops skipping.
