# Writing a vision with the owner

Use this when the owner wants to start the factory on a repo, or change what it is building. You are in a normal session with the owner (not a factory session). Your job is to turn what they want into a `VISION.md` the factory can finish cheaply: clear scope, a stated quality bar, and a short list of checkable "Done when" statements. The owner should spend about ten minutes and mostly pick between options.

Why it matters: the factory builds whatever the vision leaves open. On PAM's first day a two-sentence vision produced 37 tickets (about $3 each), including a search box, two charts and install-as-app that nobody asked for. Every vague word is paid for in tickets.

## 1. Prepare before asking anything

Do the reading yourself, so your questions are about this product, not generic:

- The repo's `README.md`, `CLAUDE.md`, any existing `VISION.md`, and `.factory/config.yml` if it exists.
- What the product has today: its pages, commands or endpoints (from the routes or the running app). Make the list; you will show it to the owner.
- If the factory has run on this repo before: the last `Factory log` comment's "Ideas for the owner", and open `factory` issues.

## 2. Draft first, then ask

Ask the owner for one or two sentences on what they want. Then write a first draft of the whole file from the template (`templates/VISION.md`) with your best guesses, and refine it by asking about the guesses. People correct a draft faster and better than they answer open questions.

Ask in small rounds (two to four questions), with the AskUserQuestion tool where the answer is a choice, and with options taken from this repo. Cover these, skipping any the owner has already answered:

1. **Outcome.** What will you do with it when this is done that you cannot do, or do not enjoy doing, today? On what device, how often?
2. **What hurts now.** The three things that annoy you most. (These become In scope and Done-when items.)
3. **Which parts.** Show the list of pages or features and ask which are in, which are fine as they are, and which do not matter. Anything fine as it is goes under Out of scope by name.
4. **New features.** Does the owner want anything that does not exist yet? Name each one. State the default out loud: anything not named will not be built, and the planner will list ideas for them to choose from.
5. **How far.** Offer three bars and say what each costs: *prototype* (works, rough, fewest tickets), *daily use* (the owner would not notice a flaw in normal use; the usual choice), *showpiece* (polished everywhere, roughly double the tickets of daily use).
6. **Freedom.** May the factory change the framework, add dependencies, change the data model, restructure the code? Default: free rein inside the scope.
7. **What stays true.** Rules that must hold whatever is built (from `CLAUDE.md`, plus anything the owner adds: approvals, data that must not appear, things that must keep working).
8. **Budget.** A ceiling on tickets for this vision, if they want one (see step 4).

## 3. Turn wishes into "Done when"

Write three to eight statements, each true or false, each something a planner can check in the running app or with a test. This is where most of the refining happens:

- **Challenge vague words.** "Better", "modern", "polished", "clean", "fast", "improve", "intuitive" cannot be checked. Ask: "What would you see on the screen if this were true?" and write down that.
- **One observable thing per statement.** "Every page works on an iPhone-size screen with no sideways scrolling" is checkable. "The app is mobile friendly" is not.
- **Name flows end to end.** "I can approve a deep dive from my phone without opening GitHub."
- **No numbers nobody measured.** A target like "Home fits in two screens" is fine only if you checked it is reachable.
- **Check it can be verified.** The factory works on invented demo data in a cloud preview. If a statement only shows up with real data or on a real device, say so in the statement, and make sure the repo's deploy has a check for it (PAM: `scripts/live_check.py`).
- **Cover every In-scope line** with at least one statement, and add no statement for something out of scope.

Read the list back to the owner in plain words and ask: "If all of these were true and nothing else changed, would you call it done?" If not, find what is missing. If something on the list would not be missed, cut it.

## 4. Size it before it starts

Estimate the tickets: roughly one per page, flow or component that has to change, plus one for any shared foundation, plus one for the cloud preview if the repo has none. Tell the owner the count and the rough cost (PAM: $1–4 a ticket on Sonnet builders, and each ticket also takes a CI run and a deploy). If it is more than they expected, offer cuts: drop a page, lower the bar, or split into a first vision and a later one. Set `daily_ticket_cap` in `.factory/config.yml` to about one and a half times the estimate, so a planner that misreads the vision cannot run far.

## 5. Check the draft

Before saving, confirm each of these and fix what fails:

- [ ] The summary is two or three sentences and describes behaviour, not implementation.
- [ ] In scope names specific pages, flows or features.
- [ ] Out of scope names what is fine as it is, and keeps the line that anything unlisted is out.
- [ ] "How far to take it" states one bar.
- [ ] Every Done-when statement is true-or-false and checkable; none uses a vague word.
- [ ] Nothing conflicts with the repo's `CLAUDE.md`; rules that bind the factory are under "What stays true".
- [ ] No secrets, personal data or real holdings.
- [ ] The owner has read the Done-when list and agreed it means done.

## 6. Save it

- Show the owner the final file. Merging it starts spending: get an explicit yes first.
- Commit it as `VISION.md` on a `claude/*` branch, open a PR, merge it. For a repo new to the factory, also follow "Onboard a repo" in the factory `README.md`.
- A changed `VISION.md` restarts planning on the next tick; nothing else is needed.

## Changing a vision later

- Add a dated section rather than rewriting, and add its Done-when statements to the list. Remove statements only when the owner no longer wants them.
- A small one-off request is cheaper as a single `factory` + `factory:ready` issue than as a vision change: the planner does not run for it.
- To stop early, the owner says so: post `**Vision met**` with the current `VISION.md sha:` on the Factory log, followed by a `factory-notified:` comment.
