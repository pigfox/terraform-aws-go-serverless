#!/bin/sh
# Hold every tests/*.tftest.hcl to the shape declared in tests/ASSERTIONS.
#
# `terraform test` cannot notice a check that is no longer there: delete an
# assert block and the file still passes, with less proven. This script closes
# that gap. It fails when:
#   - a test file's run / assert / expect_failures counts differ from the
#     manifest (in either direction: an added check must be declared too);
#   - a test file has no manifest line, or a manifest line has no file;
#   - an assertion is vacuous (condition = true), which counts as an assert
#     block but proves nothing.
#
# Counting is by line shape (`run "...`, `assert {`, `expect_failures =`), so
# it assumes the formatting `terraform fmt` produces; CI runs fmt -check first.
set -eu
cd "$(dirname "$0")/.."

manifest=tests/ASSERTIONS
fail=0

count() { grep -cE "$1" "$2" || true; }

for f in tests/*.tftest.hcl; do
  name="$(basename "$f")"
  runs="$(count '^run[[:space:]]+"' "$f")"
  asserts="$(count '^[[:space:]]*assert[[:space:]]*\{' "$f")"
  expects="$(count '^[[:space:]]*expect_failures[[:space:]]*=' "$f")"

  line="$(grep -E "^${name}[[:space:]]" "$manifest" || true)"
  if [ -z "$line" ]; then
    echo "FAIL $name: not declared in $manifest (found runs=$runs assert=$asserts expect_failures=$expects)"
    fail=1
    continue
  fi
  # shellcheck disable=SC2086 # word splitting of the manifest line is intended
  set -- $line
  if [ "$runs" != "$2" ] || [ "$asserts" != "$3" ] || [ "$expects" != "$4" ]; then
    echo "FAIL $name: declared runs=$2 assert=$3 expect_failures=$4, found runs=$runs assert=$asserts expect_failures=$expects"
    fail=1
  fi

  vacuous="$(grep -nE '^[[:space:]]*condition[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$f" || true)"
  if [ -n "$vacuous" ]; then
    echo "FAIL $name: vacuous assertion (condition = true) at line ${vacuous%%:*}"
    fail=1
  fi
done

# The pipeline only computes text; the decision is taken from the result
# afterwards, because a variable set inside a piped loop is lost with its
# subshell.
missing="$(grep -vE '^[[:space:]]*(#|$)' "$manifest" | awk '{print $1}' | while read -r name; do
  [ -f "tests/$name" ] || echo "$name"
done)"
if [ -n "$missing" ]; then
  echo "FAIL $manifest declares files that do not exist:"
  echo "$missing"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "test shape does not match $manifest"
  exit 1
fi
total="$(grep -vE '^[[:space:]]*(#|$)' "$manifest" | awk '{r+=$2; a+=$3; e+=$4} END {print r" runs, "a" asserts, "e" expect_failures"}')"
echo "every test file matches $manifest ($total)"
