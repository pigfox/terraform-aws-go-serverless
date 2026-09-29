#!/bin/sh
# Build the Go handler into build/bootstrap.zip for the provided.al2023 runtime.
#
#   ./build.sh            # arm64 (default, matches the module default)
#   GOARCH=amd64 ./build.sh   # x86_64; also set architecture = "x86_64"
#
# The binary is static (CGO off) and named bootstrap, which is what
# provided.al2023 executes. -tags lambda.norpc drops the legacy RPC mode the
# custom runtime never uses. The zip is built with fixed timestamps so an
# unchanged handler produces an unchanged hash and Terraform shows no diff.
set -eu

cd "$(dirname "$0")"
GOARCH="${GOARCH:-arm64}"

rm -rf build
mkdir -p build/stage

(
  cd app
  CGO_ENABLED=0 GOOS=linux GOARCH="$GOARCH" \
    go build -trimpath -tags lambda.norpc -ldflags='-s -w -buildid=' \
    -o ../build/stage/bootstrap .
)

touch -t 202601010000 build/stage/bootstrap
(cd build/stage && zip -q -X ../bootstrap.zip bootstrap)
rm -rf build/stage

echo "built $(pwd)/build/bootstrap.zip for linux/$GOARCH"
