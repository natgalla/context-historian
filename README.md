# context-historian

Claude Code loses context between sessions. You start fresh, re-explain what you were working on, and waste the first few minutes reconstructing state that was perfectly clear yesterday.

context-historian solves this with three hooks and one agent:

- A **stop hook** auto-saves a git-based session summary when you exit, and nudges you to run `/save` if the session was substantial
- A **session-start hook** leaves a sentinel so the system knows it's a fresh session
- A **prompt-submit hook** intercepts your first message, reads the most recent summary for the current project, and injects it as context — automatically, before Claude sees your prompt
- The **historian agent** does the real work: distilling sessions into structured summaries, loading and diffing them against the current git state, and reconstructing history from git log when no summary exists

The net effect: every session starts with context. You don't have to think about it.

---

## What gets stored

History files live at `~/.claude/history/<project-name>/YYYY-MM-DD.md`. Each file is a short structured summary under 400 words:

```
# my-app — 2025-11-14

**STATE** — On branch feat/payments. Stripe webhook handler is wired but not yet tested.

**DECISIONS**
- Use idempotency keys on all charge attempts — Stripe retries can double-charge without them

**DONE**
- Added StripeWebhookController with signature verification (app/controllers/stripe_webhook_controller.rb)
- Wired POST /webhooks/stripe route

**OPEN**
- Write integration test for the refund path

<!-- HEAD: a3f9c21 -->
```

When you have multiple day files, the agent maintains a `TIMELINE.md` — a chronological arc of the project in 1-2 bullets per day.

---

## How sessions connect

At the start of a session, the injected summary tells Claude where the project stands. At load time the agent also checks whether git has diverged since the summary was written — new commits by you or teammates get surfaced as a "since last summary" section, partitioned by author (resolved via `git config user.email`).

If no history file exists for a project, `/load` falls back to reconstructing context from `git log` — commit messages and diff stats — and presents it in the same four-section format.

---

## Installation

```bash
bash install.sh
```

The script installs the historian agent, `/load` and `/save` commands, and three hooks into `~/.claude/`, backing up any existing files first. If you already have a `CLAUDE.md` it appends the historian routing rules rather than overwriting it.

After installing, add the hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup", "hooks": [{ "type": "command", "command": "~/.claude/hooks/session-start-historian.sh" }] },
      { "matcher": "clear",   "hooks": [{ "type": "command", "command": "~/.claude/hooks/session-start-historian.sh" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/user-prompt-submit-historian.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/stop-historian.sh" }] }
    ]
  }
}
```

Then restart Claude Code.

### Manual install

```bash
mkdir -p ~/.claude/agents ~/.claude/commands ~/.claude/hooks

cp agents/historian.md   ~/.claude/agents/
cp commands/load.md      ~/.claude/commands/
cp commands/save.md      ~/.claude/commands/
cp hooks/*.sh            ~/.claude/hooks/
chmod +x                 ~/.claude/hooks/*.sh

# Append routing rules to your CLAUDE.md (or copy if you don't have one)
cat CLAUDE.md >> ~/.claude/CLAUDE.md
```

Then add the settings.json snippet above.

---

## Usage

### Automatic (no action required)

History is injected at the start of every session. The stop hook writes a git-based auto-save when you exit. For short sessions this is all you need.

### `/save` — save the current session manually

Run `/save` before `/clear` or at the end of a substantial session. The historian agent reads the conversation and git state, distills a structured summary, merges it with any auto-save from today, and writes the day file. This captures decisions and context that git log alone can't reconstruct.

### `/load` — load history manually

The prompt-submit hook handles this automatically on session start. Use `/load` when you need history from a different project, or when the hook didn't fire (e.g. you opened Claude Code in a different directory).

### BACKFILL — reconstruct history from git

If you're starting with a project that has no history files, the historian agent can reconstruct day files from `git log`. Run it as:

> "Backfill history for my projects under ~/code"

The agent finds all git repos under the base directory you specify (defaults to `$HOME` — narrow it for speed), computes a start date 90 days back by default, and writes a day file for each active day. Existing session-saved files are never overwritten.

---

## Platform notes

- **macOS** — the stop hook fires a system notification when the session transcript exceeds 300KB, prompting you to `/save` before context bloats. This uses `osascript` and is silently skipped on other platforms.
- **Date compatibility** — BACKFILL computes "90 days ago" using both BSD (`date -v-90d`) and GNU (`date -d "90 days ago"`) syntax and picks whichever works.
- **Dependencies** — `bash`, `git`, `jq`. All standard on macOS and most Linux distros.
