#!/usr/bin/env bash
# Opens one issue per title: if an open issue with this exact title exists, adds
# the new body as a comment instead of opening another.
set -euo pipefail
title=${1:?title}
body=${2:?body}
number=$(gh issue list --state open --limit 200 --json number,title |
  jq -r --arg t "$title" '.[] | select(.title == $t) | .number' | head -n 1)
if [[ -n "$number" ]]; then
  gh issue comment "$number" --body "$body"
else
  gh issue create --title "$title" --body "$body"
fi
