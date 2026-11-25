# Software factory

You describe what you want in a repo's `VISION.md`. Claude agents do the rest: plan the work as tickets, build each ticket, review it, merge it, deploy it and check it, until the vision is met. No human reviews code, PRs or merges. You write and change the vision, and you get a push notification when it is done or when something only you can fix comes up.

This repo is the factory itself: the prompts every agent follows, the templates each product repo copies, and the list of repos it works on. This README explains how it works and how to set up your own.

- [How it works](#how-it-works)
- [What is in this repo](#what-is-in-this-repo)
- [What you need](#what-you-need)
- [Set it up](#set-it-up)
- [Onboard a repo](#onboard-a-repo)
- [Day to day](#day-to-day)
- [Keeping it cheap](#keeping-it-cheap)
- [Limits and safety](#limits-and-safety)
- [Troubleshooting](#troubleshooting)

## How it works

```
 Scheduled task, hourly at :17 ──▶ Controller (fresh cloud session, Haiku; bookkeeping only)
 (+ optional GitHub "issue closed")   │ per repo in repos.yml: recover dead builders, release unblocked tickets,
                                      │ start builders for factory:ready tickets (up to max_parallel_builders),
                                      │ start a planner only when there is something new for it to do
                     ┌────────────────┴──────────────────────┐
                     ▼                                       ▼
 VISION.md ──▶ Planner (cloud session, Opus)         Builder (cloud session per ticket, Sonnet)
               runs the app's cloud preview,           branch → build → checks → verify in the running preview
               checks it against the vision's            → independent review subagent (Opus) → ship.sh:
               Done-when list, files the whole           rebase, checks, PR, CI, merge, close ticket
               remaining plan as tickets                              │
               (ready, or blocked on others),                         ▼
               posts "Vision met" when done           Deploy (the repo's own workflow, on your machine)
                                                        build → migrate → restart → smoke check
                                                        on failure: roll back + open a factory:incident ticket
```

### The roles

| Role | Where it runs | Started by | Instructions it gets | Model |
|---|---|---|---|---|
| **Controller** | a fresh claude.ai cloud session each tick | the scheduled task in [`prompts/tick.md`](prompts/tick.md) | `prompts/tick.md` (the task prompt) → `prompts/controller.md` + `prompts/controller-cloud.md` | `claude-haiku-5-5` |
| **Planner** | a cloud session with the product repo checked out | the controller (`create_session`) | `prompts/planner.md` + `prompts/github.md`, pasted in by the controller | `claude-opus-5-5` (`factory.yml` → `models.planner`) |
| **Builder** | a cloud session with the product repo checked out, one per ticket | the controller (`create_session`) | `prompts/builder.md` + `prompts/reviewer.md` + `prompts/github.md`, pasted in | `claude-sonnet-5-5` (`models.builder`) |
| **Reviewer** | a subagent inside the builder session, with none of the builder's context | the builder (Agent tool) | `prompts/reviewer.md`, the ticket and the diff | `opus` (`models.reviewer`) |
| **Deploy** | GitHub Actions on a self-hosted runner on your machine | every merge to `main` | the repo's `deploy.yml` (template in `templates/`) | none |
| **Vision writer** | your own interactive Claude Code session | you, via the `factory-vision` skill | `skills/factory-vision/SKILL.md` → `prompts/vision.md` + `templates/VISION.md` | whatever you run |

The models are pinned per role so that no session inherits whatever model happened to start it. Opus plans and reviews because a wrong ticket, or a bad merge with no human behind it, costs far more than the run itself. Sonnet builds because that is where almost all the tokens go. Haiku runs the controller because it only does bookkeeping. A repo can override any of them under `models:` in its `.factory/config.yml`.

The controller copies the prompt files into each session it starts, word for word. That is why planners and builders only ever need their own product repo: cloud sessions reach only the repo they were started with. It also means improving a prompt here improves every repo on the next tick.

### State lives in GitHub issues

There is no database. Each product repo's issues are the queue, and labels are the state machine:

| Label | Meaning |
|---|---|
| `factory` | Every factory ticket carries this. Issues without it belong to you and are never touched. |
| `factory:ready` | Can be built now. The controller hands it to the next free builder. |
| `factory:blocked` | Waits for other tickets; its body has a line `Blocked by: #a, #b`. The controller relabels it `ready` when they all close. |
| `factory:building` | A builder has it. The issue has a `factory-session: <id>` comment and `factory-heartbeat:` comments every 30 minutes. |
| `factory:stuck` | `max_attempts` builders failed. The next planner run sees it and can file a different approach. |
| `factory:incident` | Filed by a failed deploy. Built ahead of everything else, even when the vision is met. |
| `factory:bootstrap` | The ticket that creates the repo's cloud preview (`cloud_up`). Product tickets wait until it is done. |
| `factory:log` | The repo's one open `Factory log` issue: one comment per planner run, the factory's memory and your window into it. |

The controller creates these labels the first time it sees a repo.

A ticket's life: the planner files it as `ready` or `blocked`. The controller dispatches a builder and relabels it `building`. The builder ships it with `.factory/ship.sh`, which merges the PR and closes the ticket. The deploy runs on its own. If a builder dies (a usage limit, a crash) and its heartbeat is 90 minutes old, the controller puts the ticket back to `ready`. After `max_attempts` it becomes `stuck`.

### When is it done?

`VISION.md` has a **Scope** (what is wanted, what is not, how far to take it) and a **Done when** list of statements that are each true or false and checkable in the running app or by a test. A planner files tickets only for criteria that fail. It never files a feature the vision does not name: those go under "Ideas for the owner" in the Factory log, and are built only if you add them to the vision.

The controller starts a planner only when one of these holds:
- the vision changed;
- an incident or stuck ticket appeared;
- tickets closed and the queue is running low.

When every criterion is met and no factory tickets are open, the planner posts `**Vision met**` with the `VISION.md` sha. The controller then stops planning for that repo and sends you one push notification. Editing `VISION.md` starts the loop again.

### Verifying without real data

Planners and builders never touch your real data. Each product repo has a `cloud_up` script that starts the app inside a cloud session with invented or recorded demo data, and prints its URL. Agents check their work there with Playwright: text measurements first (status codes, overflow, visible text), screenshots only where something must be judged by eye, at a phone viewport and at 1440×900. Things that only show up in production are caught by the deploy's own checks, which file incidents.

## What is in this repo

| Path | What it is |
|---|---|
| `factory.yml` | Your ids (cloud environment, controller scheduled task) and the model for each role. |
| `repos.yml` | The product repos the factory works on. |
| `prompts/tick.md` | The controller's scheduled task: settings and exact prompt. |
| `prompts/controller.md` | What the controller does on each tick. |
| `prompts/controller-cloud.md` | Differences when the controller is a stateless cloud session: locks, pause, REST-only GitHub, notifications. |
| `prompts/planner.md` | How a planner measures the app against the vision and files tickets. |
| `prompts/builder.md` | How a builder builds, verifies, gets reviewed and ships one ticket. |
| `prompts/reviewer.md` | The independent reviewer's checklist. |
| `prompts/github.md` | GitHub over REST (`gh api`) from cloud sessions, where GraphQL is blocked. Given to planners and builders. |
| `prompts/vision.md` | How to interview the owner and write a good `VISION.md`. |
| `skills/factory-vision/SKILL.md` | A Claude Code skill that runs `prompts/vision.md` with you. |
| `templates/VISION.md` | Starting point for a product repo's vision. |
| `templates/config.yml` | Starting point for a product repo's `.factory/config.yml`. |
| `templates/ship.sh` | One-command shipping for builders: rebase, checks, push, PR, wait for CI, merge, close. |
| `templates/deploy.yml`, `deploy.sh`, `deploy_incident.sh` | Deploy on merge with rollback and incident tickets. |

## What you need

- **A Claude subscription with Claude Code on the web**, so you can run cloud sessions and scheduled tasks. Every factory session draws on your subscription's usage limits (see [Keeping it cheap](#keeping-it-cheap)).
- **The Claude GitHub app** installed on the factory repo and on every product repo, with access the cloud sessions can use to push (`add_repo` with `access: push` must succeed for each repo).
- **A GitHub repo per product**, with:
  - a `CLAUDE.md`;
  - checks that run without network or secrets (lint, unit tests);
  - CI on pull requests.
- **A machine that runs your apps**, with:
  - Docker;
  - a GitHub Actions self-hosted runner per repo for deploys (and for CI if hosted minutes are a problem).

  The reference setup is a Mac mini running Docker Desktop, with launchd and Caddy in front.
- **Claude Code on your own computer** (optional, but it is where you write visions with the skill).

## Set it up

1. **Copy this repo.** Fork or copy it to your own account; it can be private. Turn on *Settings → General → Automatically delete head branches*. Clone it locally to `~/factory`, the default path the vision skill and the local controller use.

2. **Create the cloud environment** that planners and builders run in: claude.ai → Claude Code → Environments, or ask a Claude Code session to create one.
   - **Network:** full (unrestricted) access. Builders install packages, pull fixtures and reach GitHub. A limited allowlist works too, if it includes everything your repos' builds need.
   - **Secrets:** no repository secrets, ever. Cloud previews run on demo data with throwaway dev keys.
   - **Setup script:** none needed. The default image has Python, Node, PostgreSQL 16, Redis and Playwright with Chromium. It has no Docker Hub pulls worth relying on and no TimescaleDB.

   Put its id (`env_…`) in `factory.yml` as `cloud_environment`.

3. **Pick your models** in `factory.yml` under `models:`. The defaults are what this factory runs.

4. **Create the controller's scheduled task** exactly as described in [`prompts/tick.md`](prompts/tick.md):
   - hourly at :17;
   - Haiku;
   - a fresh session per firing, with this repo as its source;
   - the `Claude_Code_Remote` connector;
   - push notifications on.

   Put its id (`trig_…`) in `factory.yml` as `controller_tick`. Optionally add a GitHub "issue closed" event on each product repo as a second trigger, so a closed blocker gets built without waiting for the hour.

5. **Install the vision skill** on your computer: `mkdir -p ~/.claude/skills && cp -r skills/factory-vision ~/.claude/skills/`. If your clone isn't at `~/factory`, edit the path in the copied `SKILL.md`. After that, telling Claude Code "write a vision for <repo>", or anything like it, runs the interview.

6. **Onboard your first repo** (next section). Then add it to `repos.yml` and push.

7. **Check one tick.** Fire the scheduled task by hand and open the session it starts. It should attach each repo, create the labels, open a Factory log if missing, and start a planner. The planner's first comment in the Factory log lists each Done-when criterion as met or not met, plus the tickets it filed.

## Onboard a repo

Do this once per product repo. Steps 1–3 go in one PR.

1. **Write the vision.** Run the `factory-vision` skill from a Claude Code session in the repo. It reads the repo first, drafts the whole file, asks you a few small rounds of questions, and turns your wishes into checkable Done-when statements. It then estimates the tickets and cost, and saves only after you say yes. See [`prompts/vision.md`](prompts/vision.md) for what makes a vision cheap to build: every vague word is paid for in tickets.

2. **Add `.factory/config.yml`** from [`templates/config.yml`](templates/config.yml):
   - `checks`: the commands every builder must pass, e.g. `make lint`, `make test`. They must run with no network and no secrets.
   - `daily_ticket_cap`: about 1.5× the vision's ticket estimate, so a planner that misreads the vision cannot run far.
   - `max_parallel_builders`: 2–4. More builders mean more merge conflicts and more CI queueing.
   - `max_attempts`: 3.
   - `quiet_hours_utc`: hours when no new sessions start, to keep your usage free for scheduled jobs that matter.
   - `cloud_up`: leave `null`. The first planner files a `factory:bootstrap` ticket, and a builder writes the script (start the app with demo data, print its URL) and fills this in.
   - `deploy_workflow`: your deploy workflow file.
   - `notes`: anything an agent must know that `CLAUDE.md` does not say, such as runner labels, what cloud sessions cannot reach, or which endpoints other services depend on.

3. **Add `.factory/ship.sh`**, a copy of [`templates/ship.sh`](templates/ship.sh). It must be in the repo itself, because builders cannot see this one.

4. **Give it a deploy.** Copy [`templates/deploy.yml`](templates/deploy.yml) to `.github/workflows/`, and [`deploy.sh`](templates/deploy.sh) and [`deploy_incident.sh`](templates/deploy_incident.sh) to `scripts/`. Adapt `deploy.sh` to your app. Its contract:
   - build, migrate, restart and smoke-check;
   - record the last good commit;
   - on failure, roll back to it, write the failing step and log for the incident;
   - exit non-zero.

   Register a self-hosted runner on the machine that runs the app, with a label matching `runs-on`. Until the deploy exists, the planner keeps any deploy ticket `factory:blocked`.

5. **Remove other automation** that acts on every new issue in the repo, or make it skip issues labelled `factory`.

6. **Add the repo** to `repos.yml`. On the next tick, the controller creates the labels and the `Factory log` issue and starts the first planner.

## Day to day

- **Watching.** Read each repo's `Factory log` issue: one comment per planner run, listing criteria met and not met, tickets filed, and ideas the planner did not file. Push notifications come from the controller only when you must act, or when a vision is met for the first time.
- **Changing what gets built.** Edit `VISION.md`, ideally with the skill. Add a dated section rather than rewriting, and add its Done-when statements to the list. The next tick sees the new sha and starts a planner.
- **A small one-off request.** This is cheaper than a vision change, because no planner runs. Open an issue in the product repo labelled `factory` and `factory:ready`, with a Goal and Acceptance criteria. The controller dispatches it like any ticket.
- **Pause.** Open an issue titled `Factory paused` in this repo, and close it to resume. Disabling the scheduled task also works. Running builders finish their ticket.
- **Stop early.** Post `**Vision met**` with the current `VISION.md sha:` in the Factory log, followed by a `factory-notified:` comment.
- **Stuck tickets** usually mean the ticket asked for something the environment cannot do. Read the builders' notes on the issue and either fix the cause, or close the ticket and adjust the vision.
- **Incidents** are built automatically. If the same deploy keeps failing, the cause is usually on the host (a missing `.env` value, a runner that is offline).

## Keeping it cheap

Almost all the cost is cached context re-read on every turn of a builder session. The levers are fewer sessions, fewer turns per session, and a cheaper model where judgement is not needed.

- **Fewer tickets.** Each ticket carries a fixed cost (setup, review, CI, deploy) whatever its size. A tight Scope and Done-when list is the biggest saving, and the planner bundles related fixes into one ticket per page or flow. On the first product, a two-sentence vision produced 37 tickets, many of them features nobody asked for.
- **Fewer planner runs.** The planner plans the whole remaining distance in one run, and is not started again until the queue runs low.
- **Fewer turns.** Builders make independent tool calls together and verify only the pages their ticket touches. They ship with one command (`ship.sh`) and do not wait for the deploy, which checks itself.
- **Text before images.** Agents measure pages in a script and take screenshots only for what must be judged by eye.
- **Models per role**, as above. Rough cost per ticket on Sonnet builders: $1–4, plus a CI run and a deploy.
- **Runner time.** Run CI on pull requests only. A deploy run superseded by a newer commit skips itself.

## Limits and safety

- `daily_ticket_cap` and `max_parallel_builders` per repo, and `quiet_hours_utc` to protect other scheduled work.
- All sessions draw on your subscription's usage limits. A builder cut off by a limit is re-dispatched by the controller once its heartbeat is 90 minutes old.
- No human reviews code, so the independent reviewer (Opus, no shared context) is the only gate before merge, and the deploy's smoke check plus rollback is the gate after it.
- Each repo's `CLAUDE.md` binds the factory. Anything it reserves for the owner stays reserved: for example, content you must approve, or API contracts other services depend on. Put such rules under "What stays true" in the vision too.
- Agents never commit secrets, `.env` files or real personal data. Previews use demo data and throwaway keys, and incident excerpts drop lines that look like secrets.
- The controller never changes code or merges, and never touches issues without the `factory` label.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| The tick reports `ACTION: could not attach <repo>` | The Claude GitHub app lacks access to that repo, or attaching it needs your approval. Grant access, then fire the tick again. |
| Builders start but no check runs appear on their PRs | CI is not running: hosted Actions minutes are used up, or the self-hosted runner is offline. Builders stop and say so rather than retry. Fix the runner and re-dispatch. |
| `gh pr create` / `gh issue list` fail in cloud sessions | Expected: GraphQL is blocked there. Everything uses `gh api` (REST), as in `prompts/github.md`. |
| Nothing has happened for hours | Check the scheduled task's last run. With a local controller session, look for a permission prompt nobody answered: it blocks every tick until answered. |
| The preview cannot pull images | Docker Hub is rate-limited from cloud sessions. `cloud_up` should run the app natively (local PostgreSQL 16, Redis, the app process) on demo fixtures. |
| A planner keeps filing things you did not want | The vision leaves them open. Name them under Out of scope, or tighten the Done-when statements. |
| Tickets stay `blocked` | One of the tickets in their `Blocked by:` line is still open (often a deploy ticket waiting for a runner). Close or finish it. |
