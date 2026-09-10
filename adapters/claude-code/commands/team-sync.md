---
description: Write per-day team activity files (one per commit date) showing what each teammate landed on main since your last personal day file — raw commits grouped by author, no synthesis
argument-hint: "[YYYY-MM-DD]"
allowed-tools: Bash(git:*), Bash(date:*), Bash(find:*), Bash(ls:*), Bash(mkdir:*), Read, Write
model: sonnet
---

# /team-sync

Write per-day team activity files for commits teammates landed on `main` since your last recorded session. One file per commit date, raw commit subjects grouped by author — no synthesis.

---

## Step 1 — Identify project and anchor

### 1a — Project name

```bash
git rev-parse --show-toplevel
```

Derive `<project>` from the directory basename. If git fails, report "not in a git repo" and stop.

### 1b — Anchor commit

If an explicit date argument was passed (format `YYYY-MM-DD`), use it as the anchor date and skip the day-file lookup.

Otherwise, find the most recent personal day file:

```bash
ls ~/.claude/history/<project>/*.md 2>/dev/null | grep -v TIMELINE | grep -v DECISIONS | grep -v ARCS | sort | tail -1
```

Read that file and extract the stored HEAD hash from the trailing comment:

```
<!-- HEAD: <hash> -->
```

If a hash is found, use it as `<anchor>`. If no hash is found or no day file exists, fall back to yesterday's date as the anchor with this notice: `⚠️ No saved session found — showing commits since yesterday.`

---

## Step 2 — Collect teammate commits

Get the current user's email:

```bash
git config user.email
```

Always fetch the latest remote state first:

```bash
git fetch origin main
```

Scan **`origin/main`** (not the current branch HEAD) for teammate commits since the anchor:

```bash
# If anchor is a commit hash:
git log --format="%ad|||%ae|||%an|||%s|||%H" --date=short <anchor>..origin/main

# If anchor is a date (YYYY-MM-DD):
git log --format="%ad|||%ae|||%an|||%s|||%H" --date=short --after="<anchor>" origin/main
```

Filter out any record where the author email matches the current user's email. Also filter out bot authors (emails containing `[bot]` or `noreply.github.com`).

If no teammate commits remain, output: `No teammate activity since last session.` and stop — do not write any files.

---

## Step 3 — Collect file overlap data

Get the files you have changed since the anchor:

```bash
git log --author="$(git config user.email)" --name-only --format="" <anchor>..HEAD | sort -u
```

For each teammate commit collected in Step 2, gather the files it touched:

```bash
git show --name-only --format="" <commit-hash>
```

Build a per-commit file set. A commit overlaps if any of its files appear in your changed-file set. Track which commits overlap — this is used only in Step 6 (never written to files).

---

## Step 4 — Group by date and author

Group the filtered commits by their commit date (`%ad`), then by author name within each date. Within each author group, preserve the git log order (newest first).

Structure:

```
{
  "2026-09-10": {
    "Alex Billingsley": ["commit subject A", "commit subject B"],
    ...
  },
  "2026-09-08": {
    "Alex Billingsley": ["commit subject C"],
    ...
  }
}
```

---

## Step 5 — Hand off to historian

Do not write files directly. Delegate to the historian agent with the structured data. The historian owns all writes to `~/.claude/history/` and maintains a consistent voice across all history files.

Spawn a historian agent (subagent_type: `historian`) and pass it:

- Project name and git working directory
- Anchor date or hash
- The full grouped data from Step 4 (date → author → commit subjects), presented as a structured block
- The target path pattern: `~/.claude/history/<project>/team/<date>.md`
- These formatting rules:
  - One file per date
  - One `##` section per author, in the order they appear
  - Each commit is a plain bullet (`-`) with the subject verbatim — no edits, no synthesis
  - No overlap markers in the file
  - Overwrite if a file already exists at that path

---

## Step 6 — Present to user

Show a compact index of what was written. For each date (oldest first), list the authors and their commit count. Flag any commit that overlaps with your changed files with `[!]` on that line.

Example format:

```
2026-09-05  Alex Billingsley (1)
  - harden aws estate (#220)

2026-09-08  Alex Billingsley (2)
  - Refactor security baseline: update length guard logic… [!]
  - Adjust target group deregistration delay…

2026-09-10  Alex Billingsley (2)
  - feat: implement request context management with correlation IDs (#225)
  - Add security hub finding suppressions and update terragrunt configuration (#226)
```

If a fallback notice was issued in Step 1b, prepend it. Do not print file paths unless the user asks.
