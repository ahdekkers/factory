# Software factory

The owner describes behaviour in a repo's `VISION.md`. Claude agents do everything else: plan, build, review, merge, deploy and verify. No human reviews code, PRs or merges.

## How it runs

```
 VISION.md ──▶ Planner (hourly cloud session, one scheduled task per repo)
                 │  looks at the running app (cloud preview with demo data, phone + desktop)
                 │  files small tickets as GitHub issues (label factory:ready), cap per day
                 │  fires the builder scheduled task once per ticket
                 ▼
               Builder (fresh cloud session per ticket, one shared scheduled task for all repos)
                 │  branch → build → checks → verify in the running app → independent review subagent
                 │  → PR → CI green → merge
                 ▼
               Deploy (the repo's own deploy workflow, e.g. a self-hosted runner on the Mac Mini)
                 │  deploy → smoke check → on failure: roll back + file a factory:incident issue
                 └──▶ the planner treats incidents as top priority
```

- **State lives in GitHub.** Issues are the queue (`factory`, `factory:ready`, `factory:building`, `factory:stuck`, `factory:incident`, `factory:bootstrap`). The open `Factory log` issue (label `factory:log`) has one comment per planner run: it is the factory's memory and the owner's window into it.
- **Prompts live here** (`prompts/`), so improving the factory improves every repo. Cloud sessions attach this repo with `add_repo` and read the prompts at the start of each run.
- **Per-repo files:** `VISION.md` (the owner's) and `.factory/config.yml` (the contract: checks, cloud preview script, deploy workflow, caps). See `templates/`.
- **GitHub from cloud sessions is REST-only** (`prompts/github.md`).

## Scheduled tasks (claude.ai, environment "Full Internet Access")

| Task | Schedule | Does |
|---|---|---|
| Factory: builder | none (fired by planners) | One ticket, any repo: `REPO=<owner/name> TICKET=<n>` |
| Factory: planner — `<repo>` | hourly | Plan, file tickets, dispatch builders for one repo |

Ids are recorded in `factory.yml`.

## Onboard a repo

1. Add `VISION.md` and `.factory/config.yml` (copy from `templates/`). The first planner run files a bootstrap ticket for the cloud preview if `cloud_up` does not exist yet.
2. Give the repo a deploy workflow that rolls back and files a `factory:incident` issue on failure (PAM's `.github/workflows/deploy.yml` is the reference), and turn on "Automatically delete head branches".
3. Create its planner scheduled task: copy the PAM planner's prompt, change `REPO`, and record the id in `factory.yml`.

## Limits and safety

- `daily_ticket_cap` per repo; `max_parallel_builders` per repo; `quiet_hours_utc` keep the subscription free for scheduled jobs that matter.
- All runs draw on the owner's Claude subscription limits. A builder cut off by a limit is re-dispatched by the planner after 90 minutes without a heartbeat.
- Each repo's `CLAUDE.md` binds the factory. Anything it reserves for the owner (PAM: approving investment content) stays.
- Pause everything: disable the planner scheduled tasks. Builders already running finish their ticket.
