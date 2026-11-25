# Controller tick: the scheduled task

The controller runs as a claude.ai **scheduled task** (a "routine") that starts a fresh cloud session every hour. This file is that task's configuration and prompt. The prompt text below is the exact text the task sends: if you change it here, paste it into the task too (the task stores its own copy).

| Setting | Value |
|---|---|
| Name | `Factory controller tick` |
| Schedule | `17 * * * *` (hourly at :17 UTC; avoid :00, where most scheduled jobs pile up) |
| Model | `claude-haiku-5-5` (bookkeeping only, no judgement) |
| Source repo | your factory repo (this repo) |
| Environment | the same cloud environment as `cloud_environment` in `factory.yml` |
| Each firing | creates a new session (stateless) |
| Connectors | `Claude_Code_Remote` only (gives it `create_session`, `list_sessions`, `get_session`, `add_repo`, `archive_session`) |
| Notifications | push on |
| Event triggers (recommended) | GitHub **Issues → closed** on each product repo in `repos.yml` (not the factory repo), so builders start as soon as a ticket closes. See below. |

## Prompt

```text
Software factory CONTROLLER tick.

1. Read prompts/controller.md and prompts/controller-cloud.md in this checkout (<owner>/factory). Follow both. Where they disagree, controller-cloud.md wins.
2. Read repos.yml and factory.yml. For each repo listed, attach it with add_repo (access push) before touching it.
3. Run one tick as described, then stop. Your final reply is "Nothing to report." or at most five lines, starting with "ACTION:" only if the owner must do something.

Always: GitHub is REST only (gh api, as in prompts/github.md). Never change code or merge anything. Never touch issues without the `factory` label. If a create_session or add_repo call is refused, do not retry; report it in the Factory log issue and in your final reply.
```

Replace `<owner>/factory` with your fork. The task's final reply is pushed to your phone, which is why the prompt insists on `Nothing to report.` when nothing happened.

## Creating it

From any Claude Code session that has the remote-session tools (or the claude.ai scheduled-task UI), ask:

> Create a scheduled task "Factory controller tick": cron `17 * * * *`, model claude-haiku-5-5, a new session on each firing, source repo `<owner>/factory`, environment `<cloud_environment from factory.yml>`, connector Claude_Code_Remote only, push notifications on, prompt: the text in `prompts/tick.md`.

Then fire it once by hand and read the session it starts: it should list each repo and say what it did. Then add the event triggers (next section).

## Adding the event trigger

A scheduled task can have GitHub event triggers as well as its cron schedule. Add one per product repo to the same `Factory controller tick` task. Don't create a second task: both kinds of firing should run the same prompt.

1. Make sure the Claude GitHub app is installed on the product repo. Events only arrive from repos it can see.
2. Open the task in claude.ai (Claude Code → scheduled tasks → `Factory controller tick` → edit), and add a trigger of type **GitHub event**.
3. Pick the product repo (e.g. `<owner>/<product>`) and the event **Issues**, action **closed**. Leave out other actions: `opened` and `labeled` fire constantly while the planner files tickets, and need no controller action.
4. Save, keeping the cron schedule as well. Repeat for each repo in `repos.yml`. When you onboard a new repo, add its trigger at the same time as its `repos.yml` line.

The menu names may differ slightly from these. What matters is one trigger per repo for the issue-closed event, on the existing task.

**What the session sees.** An event firing starts the same fresh Haiku session with the same prompt, plus the event payload. The prompt does not need changing: `controller-cloud.md` already says that an event tick is a normal tick, that the named issue is only a hint, and how the run-level and ticket-level locks work.

**Checking it works.** Close any `factory` ticket in a product repo (or wait for a builder to merge one). Within a minute or two a new controller session should appear in the task's run history. Its reply is either `Nothing to report.` (another tick held the lock, or nothing was ready) or the usual five-line summary. If no session appears, the GitHub app probably cannot see that repo.

**Cost.** Every closed issue in those repos starts a session, including your own non-factory issues. Ticks that find nothing to do, or find the lock held, stop after a few Haiku turns. If a repo has a lot of non-factory issue churn and that bothers you, leave its trigger off and rely on the hourly schedule.

## The other way: a long-lived controller on your Mac

Before the cloud routine, the controller was a Remote Control session on the owner's Mac, woken by a scheduled task that sent it the message `factory tick` every hour. It follows `prompts/controller.md` alone (full `gh` with GraphQL, `git pull` of a local clone). Use it if your cloud sessions cannot attach your repos. Start it with:

> You are the software factory controller. Read `~/factory/prompts/controller.md` and follow it on every message "factory tick". Reply to anything else normally.

Switch it to Haiku with `/model`, and create a scheduled task that sends `factory tick` to that session hourly. A session may not schedule its own ticks; the owner creates that task. Its weak point: it stalls if it ever waits on a permission prompt nobody answers.
