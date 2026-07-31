---
description: Load the most recent session summary for the current project. Reads the saved history file directly if one exists; falls back to the historian agent for git-log reconstruction when no file is found.
---

## Step 1 — Identify the project

Run `git rev-parse --show-toplevel 2>/dev/null` to get the repo root. If it succeeds, derive the project name from the directory basename. If not in a git repo, use `pwd` and derive from that basename.

If the basename is generic or uninformative (e.g. `/`, `home`, `Users`, or the username), treat the project as unidentified and look in the top-level fallback directory (`~/.claude/history/`) rather than a subdirectory.

## Step 2 — Find history files

Look for `.md` files (excluding `TIMELINE.md`) in:
1. `~/.claude/history/<project-name>/` — project subdirectory (identified projects)
2. `~/.claude/history/` — top-level fallback (unidentified projects)

Sort by filename date descending. Note the most recent file path.

**If no history files exist** — delegate to the historian agent with `LOAD` to reconstruct from git history. Do not continue with the steps below.

## Step 3 — Present the summary

If `TIMELINE.md` exists in the history directory, read and present it first as a project arc overview.

Then read the most recent day file in full and present it. Do not compress or reformat — the file was written to be read cold as-is.

## Step 4 — Check for git divergence

Look for a stored HEAD hash in the day file — a line matching `<!-- HEAD: <hash> -->`.

```bash
# If stored hash found:
git log --stat --format="%x1f%ad%x1f%ae%x1f%s%x1f" --date=short <stored-hash>..HEAD

# If no stored hash, fall back to date-based anchor:
git log --stat --format="%x1f%ad%x1f%ae%x1f%s%x1f" --date=short --after="<summary-date>"
```

If the project has no git repo, skip this step.

If there are no new commits since the summary, skip this step.

Partition commits by author email. Resolve the current user's email with `git config user.email`.

Synthesize a brief catch-up section under 150 words:

```
SINCE LAST SUMMARY (<date> → today)

Your changes:
- <what changed, referencing files or behavior>

Teammates:
- <Author Name>: <what they landed>
```

If all commits are by the same author, omit the grouping and write a single paragraph. If git is unavailable, skip this step entirely.
