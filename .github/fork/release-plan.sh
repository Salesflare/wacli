#!/usr/bin/env bash
# Decides whether HEAD needs a fork release, and its tag: <upstream tag>-picture.<n>.
# No release when the last release on this base has the same code (only
# .github changed since). Prints key=value lines; appends to $GITHUB_OUTPUT.
set -euo pipefail

STABLE='^v[0-9]+\.[0-9]+\.[0-9]+$'
out() {
  echo "$1=$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >>"$GITHUB_OUTPUT"; fi
}

sha=$(git rev-parse HEAD)
base=$(git tag --merged HEAD --list 'v*' | grep -E "$STABLE" | sort -V | tail -n 1)
[[ -n "$base" ]] || { echo "HEAD is not based on an upstream release tag" >&2; exit 1; }
git fetch --quiet --force origin "refs/tags/$base-picture.*:refs/tags/$base-picture.*" 2>/dev/null || true
last=$(git tag --merged HEAD --list "$base-picture.*" | sort -V | tail -n 1)
out sha "$sha"
if [[ -n "$last" ]] && git diff --quiet "$last" HEAD -- . ':(exclude).github'; then
  out release false
  out tag "$last"
  exit 0
fi
n=$(git tag --list "$base-picture.*" | sed "s/^$base-picture\.//" | sort -n | tail -n 1)
out release true
out tag "$base-picture.$(( ${n:-0} + 1 ))"
