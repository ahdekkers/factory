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
| Optional event trigger | GitHub "issue closed" on each factory repo, so builders start as soon as a blocker closes. `controller-cloud.md` has the locks that make overlapping ticks safe. |

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

Then fire it once by hand and read the session it starts: it should list each repo and say what it did.

## The other way: a long-lived controller on your Mac

Before the cloud routine, the controller was a Remote Control session on the owner's Mac, woken by a scheduled task that sent it the message `factory tick` every hour. It follows `prompts/controller.md` alone (full `gh` with GraphQL, `git pull` of a local clone). Use it if your cloud sessions cannot attach your repos. Start it with:

> You are the software factory controller. Read `~/factory/prompts/controller.md` and follow it on every message "factory tick". Reply to anything else normally.

Switch it to Haiku with `/model`, and create a scheduled task that sends `factory tick` to that session hourly. A session may not schedule its own ticks; the owner creates that task. Its weak point: it stalls if it ever waits on a permission prompt nobody answers.
