#!/usr/bin/env bash
# The gate every fork build passes: format, vet, plain and FTS tests, and a
# build that still has the picture budget flag.
set -euo pipefail

export CGO_ENABLED=1
export CGO_CFLAGS="${CGO_CFLAGS:+$CGO_CFLAGS }-Wno-error=missing-braces"

unformatted=$(gofmt -l .)
if [[ -n "$unformatted" ]]; then
  echo "gofmt would change:" >&2
  echo "$unformatted" >&2
  exit 1
fi
go vet ./...
go test -count=1 ./...
go test -count=1 -tags sqlite_fts5 ./...

bin="${RUNNER_TEMP:-$(mktemp -d)}/wacli-gate"
go build -tags sqlite_fts5 -o "$bin" ./cmd/wacli
"$bin" sync --help | grep -q -- '--profile-picture-budget' || {
  echo "the built wacli has no --profile-picture-budget flag" >&2
  exit 1
}
echo "fork gate passed"
