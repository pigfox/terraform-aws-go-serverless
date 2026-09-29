#!/bin/sh
# Fail if git tracks anything that must never be committed: Terraform state or
# plans, tfvars (where real inputs and secrets tend to live), provider working
# directories, env files, or build output. .gitignore keeps these out of a
# normal `git add`; this catches a forced add or a .gitignore edit.
set -eu
cd "$(dirname "$0")/.."

forbidden="$(git ls-files | grep -E \
  -e '(^|/)[^/]*\.tfstate($|\.)' \
  -e '(^|/)[^/]*\.tfplan$' \
  -e '(^|/)[^/]*\.tfvars(\.json)?$' \
  -e '(^|/)\.terraform/' \
  -e '(^|/)\.env($|\.)' \
  -e '(^|/)[^/]*\.env$' \
  -e '(^|/)crash(\.[^/]*)?\.log$' \
  -e '^examples/serverless-api/build/' \
  || true)"

if [ -n "$forbidden" ]; then
  echo "these tracked files must not be in git:"
  echo "$forbidden"
  exit 1
fi

# A compiled binary is recognised by its content, not its name: a bare
# `go build` names the output after the directory, so no filename rule covers it.
binaries=""
for f in $(git ls-files); do
  [ -f "$f" ] || continue
  if [ "$(head -c 4 "$f" | od -An -c | tr -d ' ')" = '177ELF' ]; then
    binaries="$binaries $f"
  fi
done
if [ -n "$binaries" ]; then
  echo "compiled binaries must not be in git:$binaries"
  exit 1
fi
echo "no state, plan, tfvars, env or build files are tracked ($(git ls-files | wc -l | tr -d ' ') files checked)"
