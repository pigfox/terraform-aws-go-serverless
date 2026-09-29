#!/bin/sh
# Run `init -backend=false` and `validate` in every root, with terraform (the
# default) or any compatible binary:
#
#   ./scripts/validate-all.sh            # terraform
#   TF=tofu ./scripts/validate-all.sh    # OpenTofu
#
# -backend=false means no backend is contacted and no credentials are needed;
# the S3 backends in examples/environments are validated but never initialised.
# Exits non-zero if any root fails, after trying all of them.
set -eu
cd "$(dirname "$0")/.."
TF="${TF:-terraform}"

failed=""
for dir in $(./scripts/roots.sh); do
  echo "== $TF validate $dir"
  if ! "$TF" -chdir="$dir" init -backend=false -input=false -no-color >/dev/null; then
    echo "init failed in $dir"
    failed="$failed $dir"
    continue
  fi
  if ! "$TF" -chdir="$dir" validate -no-color; then
    failed="$failed $dir"
  fi
done

if [ -n "$failed" ]; then
  echo "validate failed in:$failed"
  exit 1
fi
echo "validate passed in every root"
