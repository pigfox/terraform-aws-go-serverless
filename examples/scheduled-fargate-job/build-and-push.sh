#!/bin/sh
# Build the job image for linux/arm64 and push it to the ECR repository the
# module created. Run after the first `terraform apply` (which creates the
# repository), then the schedule picks the image up on its next run.
#
#   ./build-and-push.sh v1
#
# The tag must match var.image_tag. Tags are immutable, so every new build
# needs a new tag, then `terraform apply -var image_tag=<tag>`.
set -eu

TAG="${1:?usage: $0 <image-tag>}"
cd "$(dirname "$0")"

REPO="$(terraform output -raw repository_url)"
REGISTRY="${REPO%%/*}"
REGION="$(echo "$REGISTRY" | cut -d. -f4)"

aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin "$REGISTRY"

docker buildx build --platform linux/arm64 -t "$REPO:$TAG" --push job

echo "pushed $REPO:$TAG"
