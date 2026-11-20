# Software factory

The owner describes behaviour in a repo's `VISION.md`. Claude agents do everything else: plan, build, review, merge, deploy and verify. No human reviews code, PRs or merges.

## How it runs

```
 "factory tick" every hour ─────────────▶ Controller (long-lived session on the Mac Mini, light: no builds)
                                             │ per repo in repos.yml: recover dead builders, start builders for
                                             │ factory:ready tickets (up to max_parallel_builders), start a planner
                         ┌───────────────────┴───────────────────┐
                         ▼                                       ▼
 VISION.md ──▶ Planner (cloud session, hourly)          Builder (cloud session per ticket)
                 looks at the running app                  branch → build → checks → verify in the running app
                 (cloud preview, demo data,                → independent review subagent → PR → CI green → merge
                 phone + desktop), files small                       │
                 tickets in the repo's issues                        ▼
                 (factory:ready), daily cap             Deploy (the repo's own workflow; PAM: Mac Mini runner)
                                                          smoke check → on failure: roll back + factory:incident issue
```

- **State lives in each repo's GitHub issues.** Tickets carry `factory` plus a status (`factory:ready`, `factory:building`, `factory:stuck`, `factory:incident`, `factory:bootstrap`). Each repo has an open `Factory log` issue (`factory:log`) with one comment per planner run: the factory's memory and the owner's window into it. Issues without `factory` are the owner's and are never touched.
- **Prompts live here** (`prompts/`), so improving the factory improves every repo. The controller pastes them into each session it starts, so cloud sessions only ever need the one repo they work on.
- **Per-repo files:** `VISION.md` (the owner's) and `.factory/config.yml` (the contract: checks, cloud preview script, deploy workflow, caps). See `templates/`.
- **Why the controller is local:** cloud sessions can reach only the repo they were started with (attaching another needs the owner's approval), and their GitHub access is REST-only. The controller on the Mac has the owner's full `gh` login and the session tools, and does nothing heavy.

## Running pieces

`factory.yml`: the cloud environment and the controller session. Ticks are sent to the controller from outside: a recurring scheduled task cannot target a session on the owner's computer, and the controller may not schedule itself. Pause by telling the controller to pause. Running builders finish their ticket.

## Onboard a repo

1. Add `VISION.md` and `.factory/config.yml` (copy from `templates/`). The first planner run files a bootstrap ticket for the cloud preview if `cloud_up` does not exist yet.
2. Give the repo a deploy workflow that rolls back and files a `factory:incident` issue on failure (PAM's `.github/workflows/deploy.yml` is the reference), and turn on "Automatically delete head branches".
3. Add the repo to `repos.yml`. The next tick starts its planner.
4. Remove any automation that acts on every new issue in the repo, or make it skip issues labelled `factory`.

## When is it done?

Each planner run sorts what it sees into significant and minor gaps and files only significant ones. When a run finds no significant gaps and no factory tickets are open, it posts `**Vision met**` (with the `VISION.md` sha) in the Factory log, and the controller stops starting planners for that repo until the owner edits `VISION.md`. Editing the vision restarts the loop.

## Limits and safety

- `daily_ticket_cap` per repo; `max_parallel_builders` per repo; `quiet_hours_utc` keep the subscription free for scheduled jobs that matter.
- All runs draw on the owner's Claude subscription limits. A builder cut off by a limit is re-dispatched by the controller after 90 minutes without a heartbeat.
- Each repo's `CLAUDE.md` binds the factory. Anything it reserves for the owner (PAM: approving investment content) stays.
