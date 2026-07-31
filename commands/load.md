---
description: Load historical session context for the current project from a specific past date. The user-prompt-submit hook handles current-session injection automatically; use /load only to surface context from a past session.
---

## No-args case

If invoked without a date argument, do not silently load the most recent file. Instead, explain:

> The hook auto-injects current session context (STATE + OPEN) at the start of each prompt — you already have today's state. `/load` is for surfacing context from a past session. Which date would you like to load context from? (e.g. `2026-07-28`, `yesterday`, `last week`, `3 days ago`)

Wait for the user to provide a date before continuing.

## Step 1 — Resolve the date

Accept a date in any of these forms and resolve it to `YYYY-MM-DD`:

- Absolute: `2026-07-28`
- `yesterday` — today minus one day
- `last week` — today minus seven days
- `N days ago` — today minus N days

Use the current date as the reference point for relative resolution. Store the resolved date as `<target-date>`.

## Step 2 — Identify the project

Run `git rev-parse --show-toplevel 2>/dev/null` to get the repo root. If it succeeds, derive the project name from the directory basename. If not in a git repo, use `pwd` and derive from that basename.

If the basename is generic or uninformative (e.g. `/`, `home`, `Users`, or the username), treat the project as unidentified and look in the top-level fallback directory (`~/.claude/history/`) rather than a subdirectory.

## Step 3 — Locate the file

Look for `~/.claude/history/<project-name>/<target-date>.md`.

**If the file does not exist** — do not fall back to a different date silently. Tell the user:

> No summary found for `<target-date>` in this project.

Then list the available dates by reading the filenames (excluding `TIMELINE.md`) from the project history directory, sorted descending. If the directory itself does not exist, say so and stop.

## Step 4 — Present the summary

If `TIMELINE.md` exists in the project history directory, read and present it first as a project arc overview.

Then read the day file in full and present it. Label the output clearly as historical context:

```
Context from <target-date> (historical — not current state)
```

Do not present it as if it reflects live state. Do not compress or reformat — the file was written to be read cold as-is.

## Step 5 — Check for git divergence

Look for a stored HEAD hash in the day file — a line matching `<!-- HEAD: <hash> -->`.

```bash
# If stored hash found:
git log --stat --format="%x1f%ad%x1f%ae%x1f%s%x1f" --date=short <stored-hash>..HEAD

# If no stored hash, fall back to date-based anchor:
git log --stat --format="%x1f%ad%x1f%ae%x1f%s%x1f" --date=short --after="<target-date>"
```

If the project has no git repo, skip this step.

If there are no new commits since the snapshot, skip this step.

Partition commits by author email. Resolve the current user's email with `git config user.email`.

Synthesize a brief catch-up section under 150 words:

```
SINCE <target-date> SNAPSHOT (→ today)

Your changes:
- <what changed, referencing files or behavior>

Teammates:
- <Author Name>: <what they landed>
```

If all commits are by the same author, omit the grouping and write a single paragraph. If git is unavailable, skip this step entirely.
