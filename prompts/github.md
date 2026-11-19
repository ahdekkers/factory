# GitHub from a factory cloud session

GraphQL is blocked from cloud sessions: `gh issue list`, `gh issue create`, `gh pr create`, `gh pr checks`, `gh pr merge` and `gh label` fail or silently do nothing. Use the REST API through `gh api` for everything. Deleting branch refs through the API is also refused; repos delete merged branches automatically (`delete_branch_on_merge`). `git push` works. Your session can reach only the repo it was started with.

The ticket queue is the repo's own issues: label `factory` plus a status label. `R=$REPO`. Examples:

```bash
# issues
gh api "repos/$R/issues?state=open&labels=factory:ready&per_page=100" -q '.[] | select(.pull_request|not) | [.number,.title] | @tsv'
gh api "repos/$R/issues/$N" ; gh api "repos/$R/issues/$N/comments?per_page=100"
gh api -X POST "repos/$R/issues" -f title="..." -f body="$(cat body.md)" -f 'labels[]=factory' -f 'labels[]=factory:ready' -q .number
gh api -X POST "repos/$R/issues/$N/comments" -f body="..."
gh api -X POST "repos/$R/issues/$N/labels" -f 'labels[]=factory:ready'
gh api -X DELETE "repos/$R/issues/$N/labels/factory:building"
gh api -X PATCH "repos/$R/issues/$N" -f state=closed
# count factory issues created today (search API)
gh api -X GET search/issues -f q="repo:$R label:factory is:issue created:>=$(date -u +%F)" -q .total_count
# labels
gh api -X POST "repos/$R/labels" -f name=factory:ready -f color=0e8a16 2>/dev/null || true
# pull requests
gh api -X POST "repos/$R/pulls" -f title="..." -f head="$BRANCH" -f base=main -f body="$(cat pr.md)" -q .number
gh api "repos/$R/commits/$SHA/check-runs?per_page=100" -q '.check_runs[] | [.name,.status,.conclusion] | @tsv'
gh api "repos/$R/pulls/$PR" -q '.mergeable, .mergeable_state'
gh api -X PUT "repos/$R/pulls/$PR/merge" -f merge_method=merge -q .sha
# deploy run for a merge commit
gh api "repos/$R/actions/runs?head_sha=$SHA&per_page=20" -q '.workflow_runs[] | [.name,.status,.conclusion,.html_url] | @tsv'
```

Wait loops: poll every 30 s with a timeout (CI: 30 min, deploy: 45 min), never forever.
