# scheduled-fargate-job

A Go batch job in a container, run nightly on Fargate in the account's default
VPC. No load balancer, no NAT gateway, no always-on anything.

**What this costs:** about $0.04 a month: roughly $0.025 of Fargate time for a
five-minute nightly run at 0.25 vCPU / 0.5 GB on ARM64, about $0.01 for the
public IPv4 address while the task runs, and well under a cent of ECR storage for
a few-MB image. $0 while not running. (us-east-1, 2026 list prices.)

## Run it

You need Docker with `buildx` and the AWS CLI, plus a default VPC in the region
(new accounts have one).

```sh
terraform init
terraform apply                  # creates the ECR repo, cluster, schedule
./build-and-push.sh v1           # builds linux/arm64 and pushes :v1
eval "$(terraform output -raw run_task_command)"   # optional: run it now
terraform destroy
```

The job's output lands in the log group named by the `log_group_name` output.

## How it reaches ECR without NAT

The default VPC's subnets are public, so the task gets a public IP and pulls its
image over the internet gateway. Its security group has **no inbound rules** and
allows only outbound HTTPS. See [`modules/fargate-task`](../../modules/fargate-task).

## Files

- `job/main.go`: the job; logs one JSON line and exits 0. Unit test alongside.
- `job/Dockerfile`: static Go binary on `scratch`, non-root, a few MB.
- `build-and-push.sh`: logs in to ECR and pushes `linux/arm64`. Tags are
  immutable, so each build needs a new tag and `terraform apply -var image_tag=<tag>`.

## Inputs

| Name | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region. |
| `name` | `go-nightly-job` | Name for every resource. |
| `run_id` | `example` | Tag value for everything created. |
| `image_tag` | `v1` | Image tag the task runs. |
| `schedule_expression` | `cron(0 3 * * ? *)` | 03:00 UTC daily. `null` makes it run-once. |
