# Vision

The owner's intent for this repo. The software factory reads this file to decide what to build, and stops when it is met. The owner writes and changes it; Claude agents decide how to get there.

The factory builds only what this file asks for, and every ticket costs a build, a review and a deploy. The more exact the Scope and Done-when sections are, the less is spent on things you did not want. A few minutes here saves hours of agent time.

## Current vision (<date>)

<Two or three sentences: what the product should do and feel like, in the owner's words. Behaviour, not implementation.>

## Scope

**In scope**
- <Each thing you want, one line. Name the pages, flows or features. "Redesign the existing pages for phones" is clear; "make it better" is not.>

**Out of scope**
- <What the factory must not spend effort on: new features you did not list, areas that are fine as they are, rewrites.>
- Anything not listed under In scope. A planner that thinks something else would help lists it under "Ideas for the owner" in the Factory log; it is built only if the owner adds it here.

**How far to take it**
- <The quality bar, so polish has an end: e.g. "good enough that I would not notice a flaw in daily use; no pixel-level tuning", or "a prototype: working, not polished".>

## Done when

<Three to eight statements a planner can check in the running app or by a test, each true or false. The factory stops when all are true. Examples:>
1. <Every page works on an iPhone-size screen with no sideways scrolling.>
2. <I can do X from start to finish without leaving the app.>
3. <No page shows Y.>

## Freedom

Claude has free rein over design and implementation. No owner review of code, PRs or merges is needed.
<Or narrow it: "keep the current framework", "no new dependencies", "do not change the data model".>

## What stays true

<Rules from CLAUDE.md that bound the factory, if any.>
