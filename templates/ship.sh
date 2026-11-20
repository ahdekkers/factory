#!/usr/bin/env bash
# Ship a finished factory ticket in one command: rebase, checks, push, pull request, wait for CI, merge, close.
#
#   .factory/ship.sh <ticket number> "<PR title>" <PR body file>
#
# Every turn of a builder session re-reads the whole conversation, so the dozen separate steps this replaces were
# the most expensive part of a ticket. Run it once the work is committed and reviewed, with a 10-minute timeout.
# It is safe to run again: it picks up where it stopped. The last line of output says what to do next:
#   MERGED ...    done; the deploy runs on its own and files a factory:incident if it fails
#   PENDING ...   CI is still running: run the same command again
#   FAILED ...    fix what it names, commit, run again
# GitHub is reached with REST only (`gh api`), so it works in cloud sessions. Copied from the factory repo's
# templates/ship.sh: change it there.
set -uo pipefail

N=${1:?ticket number}; TITLE=${2:?PR title}; BODY=${3:?PR body file}
BUDGET=${SHIP_BUDGET:-540}        # seconds one call may take in all (checks + CI wait), under the 10-minute tool limit
START=$(date +%s)
BASE=${SHIP_BASE:-main}
say() { echo "ship: $*"; }
end() { echo "$*"; exit "${2:-1}"; }   # the last line is the verdict

cd "$(git rev-parse --show-toplevel)" || exit 1
R=$(git remote get-url origin | sed -E 's#(\.git)?$##; s#.*[:/]([^/]+/[^/]+)$#\1#')
BR=$(git rev-parse --abbrev-ref HEAD)
[ "$BR" != "$BASE" ] && [ "$BR" != HEAD ] || end "FAILED: on $BR; ship from the ticket's branch"
[ -f "$BODY" ] || end "FAILED: no PR body file $BODY"
[ -z "$(git status --porcelain --untracked-files=no)" ] || end "FAILED: uncommitted changes; commit them first"

checks() {  # the config's `checks:` list, once per commit
  local sha marker; sha=$(git rev-parse HEAD); marker="$(git rev-parse --git-dir)/factory-checked-$sha"
  [ -f "$marker" ] && return 0
  local cmd
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    say "check: $cmd"
    if ! out=$(bash -c "$cmd" 2>&1); then echo "$out" | tail -40; end "FAILED: check '$cmd' (output above)"; fi
  done < <(awk '/^checks:/{f=1;next} f&&/^[[:space:]]*-[[:space:]]/{sub(/^[[:space:]]*-[[:space:]]*/,"");sub(/[[:space:]]+#.*$/,"");print;next} f&&/^[^[:space:]#]/{f=0}' .factory/config.yml 2>/dev/null)
  touch "$marker"
}

rebase() {
  git fetch -q origin "$BASE" || end "FAILED: could not fetch origin/$BASE"
  git merge-base --is-ancestor "origin/$BASE" HEAD && return 0
  say "rebasing onto origin/$BASE"
  git rebase -q "origin/$BASE" >/dev/null 2>&1 || { git rebase --abort 2>/dev/null; end "FAILED: rebase onto origin/$BASE conflicts; rebase by hand, then run again"; }
}

for round in 1 2 3; do
  # Rebase only before the first push, or after a refused merge: rebasing an already-pushed branch every time the
  # base moves would restart CI on each call and never finish while other builders are merging.
  SHA=$(git rev-parse HEAD)
  if [ "$round" != 1 ] || [ "$(git ls-remote origin "refs/heads/$BR" | cut -f1)" != "$SHA" ]; then rebase; fi
  checks
  SHA=$(git rev-parse HEAD)
  if [ "$(git ls-remote origin "refs/heads/$BR" | cut -f1)" != "$SHA" ]; then
    git push -q --force-with-lease -u origin "$BR" 2>&1 | tail -3
    [ "$(git ls-remote origin "refs/heads/$BR" | cut -f1)" = "$SHA" ] || end "FAILED: push did not land"
    say "pushed ${SHA:0:7}"
  fi

  PR=$(gh api "repos/$R/pulls?head=${R%%/*}:$BR&state=all&per_page=5" -q '.[0] | select(.) | "\(.number) \(.state) \(.merged_at // "-")"')
  if [ -z "$PR" ]; then
    body=$(cat "$BODY")
    echo "$body" | grep -qiE "(closes|fixes|resolves) #$N([^0-9]|\$)" || body="$body"$'\n\n'"Closes #$N"
    echo "$body" | grep -q "Generated with \[Claude Code\]" || body="$body"$'\n\n'"🤖 Generated with [Claude Code](https://claude.com/claude-code)"
    PRN=$(gh api -X POST "repos/$R/pulls" -f title="$TITLE" -f head="$BR" -f base="$BASE" -f body="$body" -q .number) || end "FAILED: could not open the pull request"
    say "opened PR #$PRN"
  else
    read -r PRN state merged <<<"$PR"
    if [ "$merged" != "-" ]; then break; fi
    [ "$state" = open ] || end "FAILED: PR #$PRN is closed without a merge; reopen it or use a new branch"
  fi

  # Wait for every check run on this commit. None appearing at all means CI is not starting (billing, runner down).
  posted=0; W0=$(date +%s); WAIT=$(( BUDGET - (W0 - START) )); [ "$WAIT" -lt 45 ] && WAIT=45
  while :; do
    runs=$(gh api "repos/$R/commits/$SHA/check-runs?per_page=100" -q '.check_runs[] | [.name,.status,(.conclusion//"-")] | @tsv' 2>/dev/null)
    now=$(( $(date +%s) - W0 ))
    if [ -n "$runs" ] && ! echo "$runs" | grep -qv $'\tcompleted\t'; then break; fi
    if [ "$now" -ge "$WAIT" ]; then
      [ -n "$runs" ] && end "PENDING: CI for PR #$PRN is still running; run the same command again" 10
      [ "$now" -lt 170 ] && end "PENDING: waiting for CI on PR #$PRN to start; run the same command again" 10
      end "FAILED: no CI run has started for PR #$PRN after ${now}s. If the repo has CI, it is not starting (billing or the runner): do not retry; follow the builder instructions for a ticket you cannot finish" 4
    fi
    if [ "$posted" = 0 ]; then
      gh api -X POST "repos/$R/issues/$N/comments" -f body="factory-heartbeat: PR #$PRN open, waiting for CI" >/dev/null 2>&1; posted=1
    fi
    sleep 20
  done
  bad=$(echo "$runs" | awk -F'\t' '$3!="success" && $3!="skipped" && $3!="neutral"{print $1" ("$3")"}' | paste -sd, -)
  [ -z "$bad" ] || end "FAILED: CI on PR #$PRN: $bad. Read the logs (repos/$R/commits/$SHA/check-runs), fix, commit, run again" 5

  if msha=$(gh api -X PUT "repos/$R/pulls/$PRN/merge" -f merge_method=merge -f sha="$SHA" -q .sha 2>/dev/null) && [ -n "$msha" ]; then
    say "merged PR #$PRN as ${msha:0:7}"; break
  fi
  say "merge refused (round $round); $BASE probably moved"
  [ "$round" = 3 ] && end "FAILED: could not merge PR #$PRN after 3 rounds; check repos/$R/pulls/$PRN"
done

gh api -X POST "repos/$R/issues/$N/comments" -f body="Merged in #$PRN." >/dev/null 2>&1
gh api -X PATCH "repos/$R/issues/$N" -f state=closed >/dev/null 2>&1
gh api -X DELETE "repos/$R/issues/$N/labels/factory:building" >/dev/null 2>&1
end "MERGED PR #$PRN for ticket #$N. The deploy runs on its own; you do not need to wait for it." 0
