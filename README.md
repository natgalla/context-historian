# context-historian

Claude Code loses context between sessions. You start fresh, re-explain what you were working on, and waste the first few minutes reconstructing state that was perfectly clear yesterday.

context-historian solves this with three hooks and two agents:

- A **stop hook** auto-saves a git-based session summary when you exit, and nudges you to run `/save` if the session was substantial
- A **session-start hook** leaves a sentinel so the system knows it's a fresh session
- A **prompt-submit hook** intercepts your first message, reads the most recent summary for the current project, and injects it as context — automatically, before Claude sees your prompt
- The **historian agent** does the real work: distilling sessions into structured summaries, loading and diffing them against the current git state, and reconstructing history from git log when no summary exists
- The **researcher agent** finds answers in docs and the web rather than memory, and emits `CITE:` tags that feed the bibliography pipeline

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

## Bibliography

When a researcher finding backs a lasting decision, the historian tracks the source. The pipeline has three parts:

1. The **researcher** agent emits a `CITE:` tag after every source block:
   ```
   CITE: slug=<kebab-slug> url=<url-or-path> accessed=<YYYY-MM-DD>
   ```
2. You (or your main agent) emit a `DECISION-SOURCE:` marker when that finding grounds a lasting decision:
   ```
   DECISION-SOURCE: slug=<slug>
   ```
   In practice, Claude Code emits this automatically when it decides a finding backs a lasting decision — you only type it yourself if you're coordinating manually.
3. At `/save` time, the historian scans the session for matching marker/tag pairs and upserts entries into `BIBLIOGRAPHY.md` at the repo root.

This step is **opt-in and graceful** — if no `DECISION-SOURCE:` markers are found in a session, it silently skips. Nothing breaks if you don't use it.

`BIBLIOGRAPHY.md` entries look like this:

```markdown
### stripe-idempotency-keys

- **Source:** https://stripe.com/docs/api/idempotent_requests
- **Accessed:** 2025-11-14
- **Decision:** Use idempotency keys on all charge attempts to prevent double-charges on retry
- **Sessions:** 2025-11-14, 2025-11-21
```

---

> **Note:** The installer appends `CLAUDE.md` routing rules (historian, researcher, and bibliography conventions) to your `~/.claude/CLAUDE.md` automatically. For manual installs, see the manual install block below.

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
cp agents/researcher.md  ~/.claude/agents/
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

If you're starting with a project that has no history files, the historian agent can reconstruct day files from `git log`.

Open Claude Code in any directory and say (addressing the historian agent directly):

> "Backfill history for my projects under ~/code"

The historian agent will find all git repos under the path you name, compute a start date, and write a day file for each active day.

The agent defaults to `$HOME` as the base directory — narrow it for speed. Existing session-saved files are never overwritten.

---

## Platform notes

- **macOS** — the stop hook fires a system notification when the session transcript exceeds 300KB, prompting you to `/save` before context bloats. This uses `osascript` and is silently skipped on other platforms.
- **Date compatibility** — BACKFILL computes "90 days ago" using both BSD (`date -v-90d`) and GNU (`date -d "90 days ago"`) syntax and picks whichever works.
- **Dependencies** — `bash`, `git`, `jq`. `bash` and `git` are standard everywhere; `jq` must be installed separately on most Linux distros (`apt install jq` or `brew install jq` on macOS if not present).
- **bash version** — the hooks use `[[ ]]` conditionals that require bash 4+. macOS ships bash 3.2; install a current bash via Homebrew (`brew install bash`) if hooks misbehave on macOS.
