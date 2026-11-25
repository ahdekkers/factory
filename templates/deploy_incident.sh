#!/usr/bin/env bash
# scripts/deploy_incident.sh — open a `factory` + `factory:incident` issue for a failed deploy. Run by deploy.yml.
#   GITHUB_TOKEN, REPO, SHA are required; DRY_RUN=1 prints the issue instead of creating it.
# Reads the failed step and the log that scripts/deploy.sh leaves in $DEPLOY_STATE. Lines that look like secrets are
# dropped before the excerpt is posted. Copied from the factory repo's templates/deploy_incident.sh.
set -uo pipefail

DEPLOY_STATE="${DEPLOY_STATE:-$HOME/.app-deploy}"
step="$(cat "$DEPLOY_STATE/failed_step" 2>/dev/null || echo unknown)"
excerpt="$(tail -n 60 "$DEPLOY_STATE/deploy.log" 2>/dev/null \
  | grep -v -i -E 'key|token|secret|password|passwd|DATABASE_URL|://[^ ]*@|Authorization' || true)"
prev="$(cat "$DEPLOY_STATE/last_good" 2>/dev/null || echo none)"
sha="${SHA:?SHA required}"

# shellcheck disable=SC2016
body="$(printf 'Deploy of %s failed at step **%s**. The stack was rolled back to the last good commit (%s) where possible.\n\n```\n%s\n```\n\nRun: %s\n' \
  "$sha" "$step" "$prev" "$excerpt" "${RUN_URL:-n/a}")"
title="Deploy failed at ${step}: ${sha:0:7}"

if [ -n "${DRY_RUN:-}" ]; then
  printf 'DRY-RUN issue\ntitle: %s\nlabels: factory, factory:incident\n%s\n' "$title" "$body"
  exit 0
fi
: "${GITHUB_TOKEN:?}" "${REPO:?}"
payload="$(jq -n --arg t "$title" --arg b "$body" '{title:$t, body:$b, labels:["factory","factory:incident"]}')"
curl -fsS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/issues" -d "$payload" | jq -r .html_url
