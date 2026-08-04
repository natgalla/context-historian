---
description: Load historical session context for the current project. A single date is a file lookup; a date range delegates to the historian for a synthesized narrative. The user-prompt-submit hook handles current-session injection automatically; use /load only to surface context from a past session.
---

## No-args case

If invoked without a date argument, do not silently load the most recent file. Instead, explain:

> The hook auto-injects current session context (STATE + OPEN) at the start of each prompt — you already have today's state. `/load` is for surfacing context from a past session. Which date (or date range) would you like? (e.g. `2026-07-28`, `yesterday`, `2026-07-01 2026-07-31`)

Wait for the user to provide a date before continuing.

## Step 1 — Resolve the date(s)

Accept one or two dates. Resolve each to `YYYY-MM-DD`:

- Absolute: `2026-07-28`
- `yesterday` — today minus one day
- `last week` — today minus seven days
- `N days ago` — today minus N days

**Single date** — store as `<target-date>`, follow the single-day flow below.

**Two dates** — store as `<start-date>` and `<end-date>`, skip to the [Date range flow](#date-range-flow).

## Step 2 — Identify the project

Derive the project name using this routing rule:

```bash
PROJECT_NAME=$(git remote get-url origin 2>/dev/null | xargs basename -s .git 2>/dev/null)
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
fi
```

- **Git repo with a remote:** use the remote basename (`.git` stripped).
- **Git repo without a remote:** fall back to the git root basename.
- **No git repo:** `PROJECT_NAME` is empty — look in the `.journal/` fallback directory (`~/.claude/history/.journal/`) rather than a named subdirectory.

## Step 3 — Locate the file

Look for `~/.claude/history/<project-name>/<target-date>.md`. For a journal session (no git repo), look in `~/.claude/history/.journal/<target-date>.md` instead. If a date is explicitly requested and no file is found there, a legacy flat file may still exist at `~/.claude/history/<target-date>.md`.

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

---

## Date range flow

Do not attempt inline aggregation. Delegate to the historian:

> Spawn the historian agent with: LOAD range `<start-date>` to `<end-date>` for project `<project-name>`.

The historian reads the day entries for that range and synthesizes a narrative summary. Its output is not a concatenation of day entries — it should compress, highlight lasting decisions, and surface what's most relevant to the asker. It may be longer than a single day entry. Present it labeled as:

```
Context from <start-date> → <end-date> (historian narrative — not current state)
```

Do not present it as live state.
