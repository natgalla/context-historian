---
description: Summarize what teammates have committed on this branch since your last personal day file — grouped by author, file overlaps flagged
argument-hint: "[YYYY-MM-DD]"
allowed-tools: Bash(git:*), Bash(date:*), Bash(find:*), Bash(ls:*), Bash(cat:*), Read, Write
model: sonnet
---

# /team-sync

Show what teammates have landed on this branch since your last recorded session. Writes a team file for cross-reference by the historian at save time.

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
ls ~/.claude/history/<project>/*.md 2>/dev/null | grep -v TIMELINE | sort | tail -1
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

Collect all commits on the current branch from the anchor to HEAD, excluding the current user. Use `%x1f`/`%x1e` delimiters to safely parse multi-line output:

```bash
# If anchor is a commit hash:
git log --format="%x1f%ae%x1f%an%x1f%s%x1f%H%x1e" <anchor>..HEAD

# If anchor is a date (YYYY-MM-DD):
git log --format="%x1f%ae%x1f%an%x1f%s%x1f%H%x1e" --after="<anchor>"
```

Filter out any record where the author email matches the current user's email.

If no teammate commits remain, output: `No teammate activity since last session.` and stop — do not write a team file.

---

## Step 3 — Collect file overlap data

Get the files you have changed since the anchor:

```bash
# Hash anchor:
git diff --name-only <anchor>..HEAD -- $(git config user.email | xargs -I{} git log --author={} --format=%H <anchor>..HEAD) 2>/dev/null
# Simpler: files in commits by current user since anchor
git log --author="$(git config user.email)" --name-only --format="" <anchor>..HEAD | sort -u
```

For each teammate commit collected in Step 2, gather the files it touched:

```bash
git show --name-only --format="" <commit-hash>
```

Build a set of files each teammate touched. Identify overlaps: files present in both the current user's set and any teammate's set. These will be flagged with `[!]`.

---

## Step 4 — Compose output

Write prose grouped by author. Each author gets a short paragraph (2–4 sentences). Lead with the author name, summarize what they changed in plain language, and call out any overlapping files inline with `[!]`.

Keep the total output under 200 words. If there are many commits, synthesize — do not list every commit. Example format:

```
**Jane Smith** landed three commits updating the billing flow. She added retry logic in `payments/charge.rb` [!] and updated the Stripe webhook handler. No structural changes.

**Alex Kim** refactored the auth middleware across `middleware/auth.go` [!] and `middleware/session.go`. One commit fixed a token expiry edge case.
```

If a fallback notice was issued in Step 1b, prepend it to the output.

---

## Step 5 — Delegate team file write to historian

Do not write to `~/.claude/history/` directly. Pass the composed output to the historian agent in TEAM-FILE mode with the following context:

- `project`: the directory basename from Step 1a
- `prose`: the full output from Step 4
- `as_of_commit`: result of `git rev-parse HEAD`
- `anchor`: the anchor hash or date used in Step 1b
- `date`: today's date (YYYY-MM-DD)

The historian owns all writes to `~/.claude/history/`.

---

## Step 6 — Present to user

Output the prose from Step 4 directly. Do not print the team file path unless the user asks.
