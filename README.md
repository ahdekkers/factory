# Software factory

The owner describes behaviour in a repo's `VISION.md`. Claude agents do everything else: plan, build, review, merge, deploy and verify. No human reviews code, PRs or merges.

## How it runs

```
 hourly scheduled task ──"factory tick"──▶ Controller (one long-lived cloud session)
                                             │ starts one planner session per repo in repos.yml
                                             ▼
 VISION.md ──────────────────────────────▶ Planner (fresh cloud session per repo per hour)
                                             │ looks at the running app (cloud preview, demo data, phone + desktop)
                                             │ files small tickets as GitHub issues (factory:ready), daily cap
                                             │ starts one builder session per ticket, up to max_parallel_builders
                                             ▼
                                           Builder (fresh cloud session per ticket)
                                             │ branch → build → checks → verify in the running app
                                             │ → independent review subagent → PR → CI green → merge
                                             ▼
                                           Deploy (the repo's own workflow; PAM: self-hosted runner on the Mac Mini)
                                             │ deploy → smoke check → on failure: roll back + factory:incident issue
                                             └──▶ the planner treats incidents as top priority
```

- **State lives in this repo's GitHub issues: one queue for every repo.** Tickets carry `factory`, a status (`factory:ready`, `factory:building`, `factory:stuck`, `factory:incident`, `factory:bootstrap`) and `repo:<owner/name>`. Each repo has an open `Factory log: <repo>` issue (label `factory:log`) with one comment per planner run: the factory's memory and the owner's window into it. Tickets stay out of the target repos so their own issue automation (e.g. PAM's worker task) never picks them up. Deploy incidents are filed in the target repo; the planner mirrors any that sit unfixed for 2 hours.
- **Prompts live here** (`prompts/`), so improving the factory improves every repo. Sessions attach this repo with `add_repo` and read the prompts at the start of each run.
- **Per-repo files:** `VISION.md` (the owner's) and `.factory/config.yml` (the contract: checks, cloud preview script, deploy workflow, caps). See `templates/`.
- **Why a controller session:** sessions started by scheduled tasks created through the API get no repo access and no session tools, while sessions started with `create_session` get both. So the scheduled task only wakes the controller, and every planner and builder is started with `create_session`.
- **GitHub from cloud sessions is REST-only** (`prompts/github.md`).

## Running pieces

Recorded in `factory.yml`: the controller session id and the hourly scheduled task that wakes it. Pause everything by disabling that scheduled task; running builders finish their ticket.

## Onboard a repo

1. Add `VISION.md` and `.factory/config.yml` (copy from `templates/`). The first planner run files a bootstrap ticket for the cloud preview if `cloud_up` does not exist yet.
2. Give the repo a deploy workflow that rolls back and files a `factory:incident` issue on failure (PAM's `.github/workflows/deploy.yml` is the reference), and turn on "Automatically delete head branches".
3. Add the repo to `repos.yml`. The next tick starts its planner.

## Limits and safety

- `daily_ticket_cap` per repo; `max_parallel_builders` per repo; `quiet_hours_utc` keep the subscription free for scheduled jobs that matter.
- All runs draw on the owner's Claude subscription limits. A builder cut off by a limit is re-dispatched by the planner after 90 minutes without a heartbeat.
- Each repo's `CLAUDE.md` binds the factory. Anything it reserves for the owner (PAM: approving investment content) stays.
