#!/bin/sh
# Regenerate the inputs/outputs section of every module README with
# terraform-docs, between the BEGIN_TF_DOCS / END_TF_DOCS markers.
#
#   ./scripts/docs.sh          # rewrite the READMEs
#   ./scripts/docs.sh --check  # fail if any README is out of date (CI)
#
# Examples are documented by hand and are not regenerated.
set -eu
cd "$(dirname "$0")/.."
CONFIG="$(pwd)/.terraform-docs.yml"

mode="write"
if [ "${1:-}" = "--check" ]; then
  mode="check"
fi

stale=""
for dir in $(./scripts/roots.sh | grep -v '^examples/'); do
  if [ "$mode" = "check" ]; then
    if ! terraform-docs -c "$CONFIG" --output-check "$dir" >/dev/null; then
      stale="$stale $dir"
    fi
  else
    terraform-docs -c "$CONFIG" "$dir"
  fi
done

if [ -n "$stale" ]; then
  echo "terraform-docs output is out of date in:$stale"
  echo "run ./scripts/docs.sh and commit the result"
  exit 1
fi
[ "$mode" = "check" ] && echo "every module README matches terraform-docs"
exit 0
