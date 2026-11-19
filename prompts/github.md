# GitHub from a factory cloud session

GraphQL is blocked from cloud sessions: `gh issue list`, `gh issue create`, `gh pr create`, `gh pr checks`, `gh pr merge` and `gh label` fail or silently do nothing. Use the REST API through `gh api` for everything. Deleting branch refs through the API is also refused; repos delete merged branches automatically (`delete_branch_on_merge`). `git push` works.

Two repos are involved:
- `Q=ahdekkers/factory`: the **ticket queue for every repo**. Tickets, labels and the factory log are issues here, labelled `repo:<owner/name>` for the repo they belong to. Keeping them out of the target repos means a repo's own issue automation never sees factory tickets.
- `R=$REPO`: the code. Branches, PRs, check runs and deploy runs are here. The deploy workflow files `factory:incident` issues here.

Examples (issues on `$Q`, PRs on `$R`):

```bash
# issues
gh api "repos/$Q/issues?state=open&labels=factory:ready,repo:$R&per_page=100" -q '.[] | select(.pull_request|not) | [.number,.title] | @tsv'
gh api "repos/$Q/issues/$N" ; gh api "repos/$Q/issues/$N/comments?per_page=100"
gh api -X POST "repos/$Q/issues" -f title="..." -f body="$(cat body.md)" -f 'labels[]=factory' -f 'labels[]=factory:ready' -f "labels[]=repo:$R"
gh api -X POST "repos/$Q/issues/$N/comments" -f body="..."
gh api -X POST "repos/$Q/issues/$N/labels" -f 'labels[]=factory:building'
gh api -X DELETE "repos/$Q/issues/$N/labels/factory:ready"
gh api -X PATCH "repos/$Q/issues/$N" -f state=closed
# count issues created today (search API)
gh api -X GET search/issues -f q="repo:$Q label:\"repo:$R\" label:factory is:issue created:>=$(date -u +%F)" -q .total_count
# labels
gh api -X POST "repos/$Q/labels" -f name=factory:ready -f color=0e8a16 2>/dev/null || true   # labels live on $Q
# incidents the deploy filed on the code repo
gh api "repos/$R/issues?state=open&labels=factory:incident" -q '.[] | [.number,.title,.created_at] | @tsv'
# pull requests
gh api -X POST "repos/$R/pulls" -f title="..." -f head="$BRANCH" -f base=main -f body="$(cat pr.md)" -q .number
gh api "repos/$R/commits/$SHA/check-runs?per_page=100" -q '.check_runs[] | [.name,.status,.conclusion] | @tsv'
gh api "repos/$R/pulls/$PR" -q '.mergeable, .mergeable_state'
gh api -X PUT "repos/$R/pulls/$PR/merge" -f merge_method=merge -q .sha
# deploy run for a merge commit
gh api "repos/$R/actions/runs?head_sha=$SHA&per_page=20" -q '.workflow_runs[] | [.name,.status,.conclusion,.html_url] | @tsv'
```

Wait loops: poll every 30 s with a timeout (CI: 30 min, deploy: 45 min), never forever.
