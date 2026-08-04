# context-historian

Open Claude Code in a project. Type your first message. Claude already knows what branch you're on, what was decided last session, and where things stand right now. You didn't do anything — it just knows.

That's what context-historian does. It captures session context as you work and injects it automatically at the start of every new session, keyed to the project you're in. Switch projects, get that project's context. No configuration, no "here's where we left off" preamble. When you're ready to close, `/save` distills the session — the historian decides what context carries forward, capturing decisions and open threads without you having to curate it manually. The next session picks up from there.

Under the hood it uses three hooks and two agents:

- A **session-start hook** leaves a sentinel so the system knows it's a fresh session
- A **prompt-submit hook** intercepts your first message, reads the most recent summary for the current project, and injects it as context — automatically, before Claude sees your prompt
- A **stop hook** fires a notification when your session transcript gets large, nudging you to run `/save` while context is still live
- The **historian agent** does the real work: distilling sessions into structured summaries, loading and diffing them against the current git state, and reconstructing history from git log when no summary exists
- The **researcher agent** finds answers in docs and the web rather than memory, and emits `CITE:` tags that feed the bibliography pipeline

## How this fits with Claude Code

Claude Code already has two persistence mechanisms — they do different things and context-historian doesn't replace either of them.

**Built-in memory** tracks who you are: your preferences, role, recurring feedback, things to avoid. It's user-scoped and follows you across every project. context-historian doesn't touch it.

**`CLAUDE.md`** holds static project instructions you write and maintain manually — conventions, constraints, architecture notes that don't change session to session. context-historian doesn't replace it either; the two complement each other.

**context-historian** tracks where each project stands right now: current branch, decisions made this session, what's open, what's still in flight. It's project-scoped, session-dynamic, and updates automatically as you work.

context-historian keys history to the git root of whatever directory you open Claude Code in. Switch from `api` to `frontend` to `infra` — each project gets its own history injected automatically, with no configuration and no "which project am I in" overhead. The right context shows up because the hook reads your working directory.

The short version: built-in memory knows about you, `CLAUDE.md` knows about the project's rules, context-historian knows what happened yesterday.

## What builds up over time

The system gets more useful the longer you run it.

- **Long-term memory** — history files accumulate in `~/.claude/history/<project>/` for git-backed projects and in `~/.claude/history/.journal/` for non-git sessions. `TIMELINE.md` grows into a chronological arc of the project — what the branch looked like in November, what changed in January, what's open now. The context injected on day 90 is richer than day 1.

- **Hands-off documentation** — every `/save` is a structured journal entry: what was built, what was decided, what's still open. Over a long engagement this becomes a complete record of the project's evolution without anyone sitting down to write it up.

- **Stale memory detection** — the historian checks project memories at each `/save` and flags entries that no longer match reality. Outdated memories get retired rather than silently misleading future sessions.

- **Project-specific memory curation** — memories are scoped per project and curated separately from Claude Code's global user memory. During `/save`, the historian surfaces memories that may be worth promoting to `CLAUDE.md` — you review and apply them.

- **Backfillable** — already have a project with months of git history but no historian files? BACKFILL reconstructs day files from `git log` so you're not starting from zero. Existing session-saved files are never overwritten.

- **History integrity** — if you ask the historian agent to amend a prior summary, it surfaces the request, quotes the contested text, and requires explicit justification before touching anything. Requests to soften wording or revise narrative without a demonstrable factual error are declined. This covers agent-mediated changes — you can always edit the files directly, and sometimes that's the right call. The protection exists so casual revision requests don't slip through unexamined.

---

## What gets stored

History files live at `~/.claude/history/<project-name>/YYYY-MM-DD.md`. For sessions with no git repo — stand-alone tasks, exploratory sessions, anything outside a project directory — files go to `~/.claude/history/.journal/YYYY-MM-DD.md` and the file header uses `journal` as the project label. Each file is a short structured summary under 400 words:

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

When you open Claude Code and type your first message, the prompt-submit hook fires before Claude sees it. It reads the most recent history file for the current project and injects it as context — silently, automatically. By the time Claude responds to your first message, it already knows where the project stands.

If the history file exceeds 3000 characters, the hook injects only the STATE and OPEN sections rather than the full file, to avoid bloating the context window. A note is appended pointing to `/load` for the complete entry.

`/load` is for surfacing context from a past session, not the current one. Run it with a date — `2026-07-28`, `yesterday`, `last week`, `3 days ago` — and it finds that day's history file, labels it as historical context, and runs a divergence check to show what changed between that snapshot and today. If no file exists for the requested date, it lists what's available instead of silently falling back. If invoked with no date, `/load` explains that the hook already injected current session context and prompts you to specify a date or date range.

Pass two dates to get a narrative across a range — `/load 2026-07-01 2026-07-31`. This delegates to the historian agent, which reads the day files for that span and synthesizes an arc: key decisions, significant work, and what was open at the end of the period. It's an editorial summary, not a concatenation — only what's in the day files, nothing inferred.

If no history file exists for a project at all, use BACKFILL to reconstruct a scaffold from `git log` — branch state, recent commits, and diff stats. This is a cold-start aid, not a real substitute: it can only surface what's in your commit messages. Decisions, reasoning, and open questions that never made it into a commit are invisible to it. Run `/save` at the end of sessions where those things matter.

**Session-opening questions:** The routing rules installed by `install.sh` (this repo's `CLAUDE.md`, appended to your `~/.claude/CLAUDE.md`) already include a rule telling Claude to answer session-opening questions ("what's next?", "where did we leave off?", "catch me up") directly from the injected context rather than spawning the historian or re-reading history files as a ritual. If you're upgrading from an earlier version or used a partial manual install, verify your `~/.claude/CLAUDE.md` includes a "Session-opening questions" section — if not, add this:

```
When responding to session-opening questions ("what's next?", "where did we leave off?", "catch me up"), the prompt-submit hook has already injected project context — answer directly using it. Do not narrate a state check or re-read history files as a ritual before answering.
```

---

## Costs and tradeoffs

**What's free:** context injection at session start is a local file read — no LLM call, no tokens. The stop hook notification is a bash script. Neither costs anything.

**What costs tokens:** `/save` runs a pre-check first — if no commits, tool calls, or file changes occurred this session, it reports "Nothing to save" and stops without invoking the historian. When there is something to save, it makes one LLM call — the historian agent reads the conversation and distills a structured summary. In practice this is a small, focused call, and it pays back quickly: a single `/save` typically costs less than the tokens you'd spend re-establishing context at the start of the next session.

**`/save` is optional.** For short sessions with no lasting decisions, skip it — the git log scaffold at next session start is usually enough to re-orient. Run `/save` when decisions were made, when something was learned that git can't capture, or when the session was long enough that re-establishing context manually would be painful.

**What git log can't do.** Git log reconstruction gives you orientation — branch, recent commits, what changed. It cannot give you context: why a decision was made, what was tried and abandoned, what's still open. Those only exist in the conversation. If your commit messages captured all of that, your git history would be bloated and unusual. `/save` is the right place for it.

---

## Bibliography

This section is only relevant if you use the researcher agent. If you don't, skip it — nothing in the core workflow depends on it.

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

> **Canonical source:** `historian.md` and the related skill and hook files originate in a private upstream repo and are propagated here. Direct edits to these files in context-historian may be overwritten — this repo is the authoritative community release.

> **macOS prerequisite:** macOS ships bash 3.2, but the hooks require bash 4+. Install a current bash before running anything: `brew install bash`. Without it, hooks will silently misbehave and context injection won't work.

```bash
bash install.sh
```

The script installs the historian and researcher agents, `/load`, `/save`, and `/team-sync` commands, and three hooks into `~/.claude/`, backing up any existing files first. If you already have a `CLAUDE.md` it appends the historian routing rules rather than overwriting it.

After installing, add the hooks to `~/.claude/settings.json` (Claude Code's global config — create it if it doesn't exist):

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

The `startup` and `clear` matcher values are Claude Code's built-in SessionStart triggers — `startup` fires when you open a new session, `clear` fires on `/clear`.

Then restart Claude Code.

**Minimum install:** the `SessionStart` and `UserPromptSubmit` hooks handle automatic context injection. The `Stop` hook is optional — it only adds the size notification nudge.

### Manual install

```bash
mkdir -p ~/.claude/agents ~/.claude/commands ~/.claude/hooks

cp agents/historian.md    ~/.claude/agents/
cp agents/researcher.md   ~/.claude/agents/
cp commands/load.md       ~/.claude/commands/
cp commands/save.md       ~/.claude/commands/
cp commands/team-sync.md  ~/.claude/commands/
cp hooks/*.sh             ~/.claude/hooks/
chmod +x                  ~/.claude/hooks/*.sh

# Append this repo's routing rules to your global ~/.claude/CLAUDE.md (or copy if you don't have one).
# The rules tell Claude to delegate /save and /load to the historian agent,
# use the researcher agent for documentation lookups, and emit DECISION-SOURCE markers.
cat CLAUDE.md >> ~/.claude/CLAUDE.md
```

Then add the settings.json snippet above.

---

## Usage

### Automatic (no action required)

History is injected at the start of every session. The stop hook watches transcript size and notifies you when a manual `/save` is worth running. For short sessions where no lasting decisions were made, git log reconstruction at the next session start is usually sufficient. Use BACKFILL to cold-start a project that has no saved summaries yet.

### `/save` — save the current session manually

Run `/save` before `/clear` or at the end of a substantial session. The historian agent reads the conversation and git state, distills a structured summary, and writes the day file. This captures decisions and context that git log alone can't reconstruct.

### `/team-sync` — see what teammates have landed

Run `/team-sync` to get a plain-English summary of commits by other authors since your last saved session. File overlaps are flagged with `[!]` so you can spot areas where your work and a teammate's may collide.

The summary is written to a team file in `~/.claude/history/<project>/team/` and cross-referenced by the historian at next `/save` — if an OPEN item touches the same file a teammate just changed, the OPEN bullet gets annotated automatically.

Accepts an optional date override: `/team-sync 2026-07-28` to look back from a specific day rather than the last session anchor.

### BACKFILL — reconstruct history from git

If you're starting with a project that has no history files, the historian agent can reconstruct day files from `git log`.

Open Claude Code in any directory and ask in plain English:

> "Backfill history for my projects under ~/code"

The historian agent will find all git repos under the path you name, compute a start date, and write a day file for each active day.

The agent defaults to `$HOME` as the base directory — narrow it for speed. Existing session-saved files are never overwritten.

---

## Platform notes

- **Notifications** — the stop hook fires a notification when the session transcript exceeds 300KB. On macOS this uses `osascript`; on Linux desktop it falls back to `notify-send` (`apt install libnotify-bin` / `dnf install libnotify`). Windows and headless environments get no notification — the hook silently skips.
- **Date compatibility** — BACKFILL defaults to commits from the past day (yesterday onward). When passing a date range override, both BSD (`date -v-Nd`) and GNU (`date -d "N days ago"`) syntax are accepted; the agent picks whichever works on the current platform.
- **Dependencies** — `bash`, `git`, `jq`. `bash` and `git` are standard everywhere; `jq` must be installed separately on most Linux distros (`apt install jq` or `brew install jq` on macOS if not present). `gh` (GitHub CLI) is optional — if present and authenticated, `/save` and BACKFILL will pull in PR activity automatically.
- **bash version** — `install.sh` uses `[[ ]]` conditionals that require bash 4+. macOS ships bash 3.2 by default, which will cause the installer to fail — install a current bash via Homebrew (`brew install bash`) before running anything on macOS.
