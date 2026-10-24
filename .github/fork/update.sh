#!/usr/bin/env bash
# Moves this fork onto the newest upstream release tag.
#
# The fork is: <upstream release tag> + our patch commits + our "fork:" tooling
# commits. This script finds the upstream tag HEAD is based on and the newest
# upstream release tag, then:
#   current            HEAD is already on the newest tag
#   rebased            our commits rebased cleanly onto the newest tag (branch)
#   conflict           the rebase stopped on a conflict (nothing left behind)
#   upstream-has-patch upstream ships the feature itself; the branch is the new
#                      tag plus only the "fork:" tooling commits
# It prints key=value lines and appends them to $GITHUB_OUTPUT when set.
set -euo pipefail

UPSTREAM_URL=${UPSTREAM_URL:-https://github.com/openclaw/wacli.git}
FEATURE_MARKER=${FEATURE_MARKER:-profile-picture-budget}
STABLE='^v[0-9]+\.[0-9]+\.[0-9]+$'

out() {
  echo "$1=$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >>"$GITHUB_OUTPUT"; fi
}

newest() { grep -E "$STABLE" | sort -V | tail -n 1; }

mapfile -t upstream_tags < <(git ls-remote --tags --refs "$UPSTREAM_URL" 'v*' | awk '{ sub("refs/tags/", "", $2); print $2 }' | grep -E "$STABLE")
[[ ${#upstream_tags[@]} -gt 0 ]] || { echo "no upstream release tags found" >&2; exit 1; }
refspecs=()
for tag in "${upstream_tags[@]}"; do refspecs+=("+refs/tags/$tag:refs/tags/$tag"); done
git fetch --quiet --no-tags "$UPSTREAM_URL" "${refspecs[@]}"

latest=$(printf '%s\n' "${upstream_tags[@]}" | newest)
base=$(git tag --merged HEAD --list 'v*' | newest)
[[ -n "$base" ]] || { echo "HEAD is not based on an upstream release tag" >&2; exit 1; }
out base "$base"
out latest "$latest"
out old_head "$(git rev-parse HEAD)"

if [[ "$(printf '%s\n%s\n' "$base" "$latest" | sort -V | tail -n 1)" == "$base" ]]; then
  out state current
  exit 0
fi

# Our commits since the base tag, oldest first. "fork:" commits are tooling.
mapfile -t tooling < <(git log --reverse --format='%H %s' "$base..HEAD" | awk '$2 == "fork:" { print $1 }')

if git grep -q -- "$FEATURE_MARKER" "$latest" -- cmd/wacli; then
  branch="fork/track-$latest"
  git checkout --quiet -B "$branch" "$latest"
  if [[ ${#tooling[@]} -gt 0 ]] && ! git cherry-pick "${tooling[@]}" >/dev/null; then
    git cherry-pick --abort || true
    out state conflict
    exit 0
  fi
  out branch "$branch"
  out state upstream-has-patch
  exit 0
fi

branch="fork/update-$latest"
git checkout --quiet -B "$branch" HEAD
if git rebase --onto "$latest" "$base" >/dev/null; then
  out branch "$branch"
  out state rebased
else
  git rebase --abort || true
  out state conflict
fi
