# serverless-api

The whole root module end to end: a small Go HTTP handler built into a Lambda
zip, deployed behind an HTTP API.

**What this costs:** $0.00 a month idle. Inside the free tier (1M Lambda
requests, 1M API requests in an account's first year) a demo costs nothing;
past it, about $1.28 per million requests at the 128 MB default ($1.00 API, $0.20 Lambda requests, $0.08 Lambda compute at 50 ms). Reserved
concurrency is capped at 2, so a flood of traffic is throttled rather than billed.

## Run it

```sh
./build.sh            # Go -> build/bootstrap.zip (linux/arm64, reproducible)
terraform init
terraform apply
curl "$(terraform output -raw api_endpoint)/anything"
terraform destroy
```

```json
{"message":"hello from Go on AWS Lambda","method":"GET","path":"/anything","run_id":"example"}
```

`run_id` in the response comes from the function's environment, which is how
the Terratest suite knows the answer came from the deployment it just made.

## Files

- `app/main.go`: the handler (API Gateway payload format 2.0), with a unit test
  in `app/main_test.go`.
- `build.sh`: static `CGO_ENABLED=0` build named `bootstrap`, zipped with fixed
  timestamps so an unchanged handler gives an unchanged hash and no diff.
  `GOARCH=amd64 ./build.sh` builds for x86_64; then also set
  `architecture = "x86_64"`.
- `main.tf`: calls the root module with the zip and `reserved_concurrency = 2`.

## Inputs

| Name | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region. |
| `name` | `go-serverless-hello` | Function and API name. |
| `run_id` | `example` | Tag value for everything created. |
| `zip_path` | `build/bootstrap.zip` | The zip from `build.sh`. |
