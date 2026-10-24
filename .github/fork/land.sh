#!/usr/bin/env bash
# Lands a clean rebase: pushes the branch, opens a PR into main, waits for any
# checks on it, then moves main to the branch head. GitHub marks the PR merged
# because its head is now main. Needs BRANCH, BASE, LATEST, OLD_HEAD, RUN_URL.
set -euo pipefail

fail() {
  bash .github/fork/issue.sh "Auto-update to upstream $LATEST needs review" "The rebase onto $LATEST was clean and passed the gate, but landing it failed: $1. Run: $RUN_URL"
  exit 1
}

git push --force origin "HEAD:refs/heads/$BRANCH" ||
  fail "pushing $BRANCH was refused (upstream changed workflow files? then the FORK_BOT_TOKEN secret needs the Workflows permission)"
sha=$(git rev-parse HEAD)

pr=$(gh pr list --head "$BRANCH" --state open --json number --jq '.[0].number // empty')
if [[ -z "$pr" ]]; then
  body="Moves the fork from upstream $BASE to $LATEST. The patch rebased without conflicts and passed the gate (format, vet, plain and FTS tests, flag check). This PR lands by itself once its checks pass; the release follows. Run: $RUN_URL"
  url=$(gh pr create --base main --head "$BRANCH" --title "Rebase on upstream $LATEST" --body "$body") || fail "opening the PR failed"
  pr=${url##*/}
fi

# Wait up to two minutes for checks to appear (PRs opened with the default
# token start none), then for all of them to pass.
checks=0
for _ in $(seq 1 12); do
  checks=$(gh pr checks "$pr" --json name --jq length 2>/dev/null || echo 0)
  [[ "$checks" -gt 0 ]] && break
  sleep 10
done
if [[ "$checks" -gt 0 ]]; then
  gh pr checks "$pr" --watch --interval 30 --fail-fast || fail "checks on PR #$pr failed"
fi

git push --force-with-lease="main:$OLD_HEAD" origin "HEAD:main" || fail "moving main was refused"
sleep 5
if [[ "$(gh pr view "$pr" --json state --jq .state)" != "MERGED" ]]; then
  gh pr close "$pr" --comment "Landed: main is now $sha." || true
fi
git push origin --delete "$BRANCH" || true
