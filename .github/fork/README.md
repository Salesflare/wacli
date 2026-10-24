# Salesflare/wacli fork

This fork is upstream [openclaw/wacli](https://github.com/openclaw/wacli) at its newest release tag, plus one patch: `wacli sync --follow --profile-picture-budget N`, which lets read-only `profile picture-info` look up people's profile pictures through the running sync process, at most N a day. The patch is offered upstream; once upstream ships it, this fork is no longer needed.

`main` = upstream release tag + the patch commit(s) + `fork:` tooling commits (this folder and the two `fork-*` workflows). Releases are tagged `<upstream tag>-picture.<n>`, for example `v0.25.0-picture.1`.

## Daily auto-update (`fork-update.yml`)

1. Finds the newest upstream release tag. If main is already on it, it only releases when the code changed since the last release.
2. Otherwise it rebases our commits onto the new tag and runs the gate (`test.sh`: gofmt, vet, plain and FTS Go tests, flag check).
3. Clean and green: it opens a PR, waits for its checks, moves main to the rebased head (GitHub marks the PR merged), and releases (`fork-release.yml`: linux amd64/arm64, windows amd64, darwin amd64/arm64, `checksums.txt`, build provenance attestation).
4. Conflict or red gate: an AI step (Codex through Salesflare's Azure OpenAI APIM, the same setup as the AI PR reviews) resolves it on `fork/ai-update-<tag>` and opens a PR for review, plus one issue. Nothing is merged. To accept, run **Fork update** with `promote` = that branch.
5. Upstream ships the patch: main becomes the upstream tag plus the tooling only, no more releases, and an issue says to switch back to upstream.

## Setup

- `FORK_BOT_TOKEN` secret: a fine-grained token for this repository with Contents, Pull requests, Issues and Workflows read/write. Needed because upstream releases often change workflow files, which the default token may not push.
- The AI step uses the org secret `AZURE_APIM_KEY_REVIEWER` and the org variables `AZURE_APIM_BASE_URL_REVIEWER` and `AZURE_OPENAI_MODEL_REVIEWER`; this repository must be in their selected repositories. Without them, a conflict only opens the issue.
