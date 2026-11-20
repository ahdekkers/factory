# Software factory

The owner describes behaviour in a repo's `VISION.md`. Claude agents do everything else: plan, build, review, merge, deploy and verify. No human reviews code, PRs or merges.

## How it runs

```
 "factory tick" every hour ─────────────▶ Controller (long-lived session on the Mac Mini, light: no builds)
                                             │ per repo in repos.yml: recover dead builders, release blocked tickets,
                                             │ start builders for factory:ready tickets (up to max_parallel_builders),
                                             │ start a planner only when there is something new for it to do
                         ┌───────────────────┴───────────────────┐
                         ▼                                       ▼
 VISION.md ──▶ Planner (cloud session, a few runs)      Builder (cloud session per ticket)
                 checks the running app against            branch → build → checks → verify in the running app
                 the vision's Done-when list,              → independent review subagent → PR → CI green → merge
                 files the whole remaining plan                      │
                 as tickets (ready or blocked),                      ▼
                 stops at "Vision met"                  Deploy (the repo's own workflow; PAM: Mac Mini runner)
                                                          smoke check → on failure: roll back + factory:incident issue
                                                          → phone-size check of the live app → incident if it finds any
```

- **State lives in each repo's GitHub issues.** Tickets carry `factory` plus a status (`factory:ready`, `factory:blocked` with a `Blocked by: #n` line, `factory:building`, `factory:stuck`, `factory:incident`, `factory:bootstrap`). Each repo has an open `Factory log` issue (`factory:log`) with one comment per planner run: the factory's memory and the owner's window into it. Issues without `factory` are the owner's and are never touched.
- **Prompts live here** (`prompts/`), so improving the factory improves every repo. The controller pastes them into each session it starts, so cloud sessions only ever need the one repo they work on.
- **Models are pinned per role** in `factory.yml` (`models:`), so a session never inherits whatever the controller runs on: Opus plans and reviews, Sonnet builds, and the controller itself should run on Haiku.
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

`VISION.md` carries a **Scope** (what is wanted, what is not, how far to take it) and a **Done when** list of checkable statements. A planner files tickets only for criteria that fail, never for features the vision does not name (those go to "Ideas for the owner" in the log). The controller starts a planner only when the vision changed, an incident or stuck ticket appeared, or tickets closed and the queue is running low. When every criterion is met and no factory tickets are open, the planner posts `**Vision met**` (with the `VISION.md` sha) in the Factory log, and the controller stops starting planners for that repo until the owner edits `VISION.md`. The controller sends the owner one push notification when that happens. Editing the vision restarts the loop.

## Keeping it cheap

Almost all the cost is cached context re-read on every turn of a builder session, so the levers are: fewer sessions, fewer turns per session, a cheaper model where judgement is not needed.

- **Fewer tickets.** Each one carries a fixed cost (setup, review, CI, deploy) whatever its size. A tight Scope and Done-when list is the biggest saving; the planner bundles related fixes into one ticket per page or flow.
- **Fewer planner runs.** The planner plans the whole remaining distance in one run and is not started again until the queue runs low.
- **Fewer turns.** Builders wait for CI and deploys with one blocking command, batch shell commands, and verify only the pages their ticket touches.
- **Text before images.** Planners and builders measure pages in a script (status, overflow, sizes, visible text) and take screenshots only for what must be judged by eye.
- **Models per role** (`factory.yml`).
- **Runner time.** With one self-hosted runner, CI on pull requests only; a deploy run superseded by a newer commit skips itself.

## Limits and safety

- `daily_ticket_cap` per repo; `max_parallel_builders` per repo; `quiet_hours_utc` keep the subscription free for scheduled jobs that matter.
- All runs draw on the owner's Claude subscription limits. A builder cut off by a limit is re-dispatched by the controller after 90 minutes without a heartbeat.
- Each repo's `CLAUDE.md` binds the factory. Anything it reserves for the owner (PAM: approving investment content) stays.
