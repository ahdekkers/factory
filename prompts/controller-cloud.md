# Running the controller as a cloud routine

Read this together with `controller.md`. Where they disagree, this file wins. It applies when the tick is a claude.ai scheduled task that starts a fresh cloud session each hour (Haiku), instead of a long-lived session on the Mac.

## What is different

- **You are stateless and one-shot.** Nothing carries over from the last tick. Everything you need is in GitHub: ticket labels, `factory-session:` comments, the `Factory log` issue. Do the tick, reply, stop.
- **Your checkout is `ahdekkers/factory`** (the routine's source). Do not `git pull`; the prompts you are reading are already current. Read `repos.yml` and `factory.yml` from it.
- **Attach each repo before touching it.** For every repo in `repos.yml`, call `add_repo` (owner, repo, `access: push`). If any call is refused or waits for approval, do not retry: finish the repos that did attach, and make your final message start with `ACTION: could not attach <repo>: <reason>`.
- **GitHub is REST only.** GraphQL is blocked: `gh issue list`, `gh pr ...` and `gh label` fail. Use `gh api` as in `github.md` for every read and write (it is the same guide builders get). Read a repo's config with `gh api repos/<repo>/contents/.factory/config.yml -H 'Accept: application/vnd.github.raw'`.
- **Starting sessions** works as in `controller.md` (`create_session` with environment, model, source, prompt). Sessions you start are your children; list them with `list_sessions` (`children: true`). Do not start a builder or planner for a repo if `add_repo` for it failed.

## Event ticks and the lock

Besides the hourly schedule, a tick also starts when a `factory` issue is closed in a repo (a GitHub event). Several can arrive within a minute, so ticks must not overlap:

1. **Run-level lock.** Before anything else, `list_sessions` and look for another session titled like yours (`Factory controller tick`) that is still working and started in the last 10 minutes. If one exists, reply `Nothing to report.` and stop: it will see what you would have seen. The hourly tick is the safety net for anything missed.
2. **Ticket-level lock.** Before `create_session` for a ticket, relabel it `factory:building`, then re-read its comments. If a `factory-session:` comment already appeared since you started, someone else took it: skip it. Only after `create_session` succeeds, comment `factory-session: <id>`.
3. **An event tick is a normal tick**, with the same steps and caps. If the event message names the closed issue, it is only a hint: re-read the queue rather than trusting it.

## Pause

Pause without touching the routine: if `ahdekkers/factory` has an open issue titled `Factory paused`, start nothing, change nothing, and reply `paused`. Close the issue to resume. (Disabling the routine also pauses it.)

## Notifying the owner

Use the `PushNotification` tool if you have it. If you do not, put the message in your final reply starting with `ACTION:`; the routine pushes your final reply to the owner's phone.

## Final reply

If nothing needed doing: exactly `Nothing to report.` Otherwise at most five lines as in `controller.md`. Start the reply with `ACTION:` only when the owner must do something (a refused attach, a ticket blocked on something outside the repo, vision met for the first time). Do not repeat an `ACTION:` the Factory log already records with `factory-notified`.
