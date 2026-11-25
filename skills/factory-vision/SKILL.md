---
name: factory-vision
description: Help the owner write or change a VISION.md for the software factory. Use when they want to start the factory on a project, give it a new goal, add to or refine a vision, or ask what to put in a vision file. Interviews the owner, drafts the file, sizes the work and saves it.
---

# Write a factory vision

The guide lives in the factory repo so it stays in step with the planner's rules. `FACTORY` below is your local clone of it (default `~/factory`; change this line if yours is elsewhere).

1. `git -C $FACTORY pull --ff-only` (ignore a failure), then read `$FACTORY/prompts/vision.md` and `$FACTORY/templates/VISION.md`.
2. Follow `prompts/vision.md` step by step with the owner: prepare, draft first, ask in small rounds, turn wishes into Done-when statements, size the work, run the checklist, and save only after an explicit yes.
3. If the target repo is not obvious from the conversation, ask which project the vision is for before anything else.
