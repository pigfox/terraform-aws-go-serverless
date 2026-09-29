#!/bin/sh
# Print every Terraform root in the repo, one per line: the root module, each
# module under modules/, and each example. Derived from the tree (any directory
# holding a versions.tf) rather than listed, so a new module or example is
# checked the moment it exists and cannot be forgotten by a list.
set -eu
cd "$(dirname "$0")/.."
find . -name versions.tf -not -path '*/.terraform/*' -exec dirname {} \; | sed 's|^\./||' | sort
