# context-historian

Open your agent in a project. Type your first message. It already knows what branch you're on, what was decided last session, and where things stand right now. You didn't do anything — it just knows.

That's what context-historian does. It captures session context as you work and injects it automatically at the start of every new session, keyed to the project you're in. Switch projects, get that project's context. No configuration, no "here's where we left off" preamble. When you're ready to close, `/save` distills the session — the historian decides what context carries forward, capturing decisions and open threads without you having to curate it manually. The next session picks up from there.

Under the hood it has two layers. The **skills layer** (`skills/`) carries the historian and researcher procedures — harness-agnostic, with no tool-name assumptions or harness-specific paths. The **adapter** (`adapters/`) wires those skills into your specific harness via hooks, agents, and commands. The automatic injection requires your harness to support session-start and prompt-submit events — without those hooks (or equivalent middleware), context injection falls back to a manual `/load` workflow. Hooks are the prerequisite for the "it just knows" experience.

## Building an adapter

An adapter is a thin connector between `skills/` and a specific agent harness. It doesn't implement historian or researcher logic — those live in the skills layer. What it implements is injection (delivering context at the right moment), command registration (exposing `/save`, `/load`, and `/team-sync` to the user), and routing rules (telling the harness when to delegate to which agent).

To build one, start with `adapters/README.md`, which specifies the adapter contract. Then use `adapters/claude-code/` as the reference — it covers the full surface area. As a rough sizing guide, a minimal adapter is approximately 200 lines of TypeScript plus a routing-rules file, most of which is harness plumbing rather than historian logic.

## What builds up over time

The system gets more useful the longer you run it.

- **Long-term memory** — history files accumulate in `$HISTORY_ROOT/<project>/` for git-backed projects and in `$HISTORY_ROOT/.journal/` for non-git sessions (the default `$HISTORY_ROOT` for Claude Code is `~/.claude/history`). `TIMELINE.md` grows into a chronological arc of the project — what the branch looked like in November, what changed in January, what's open now. The context injected on day 90 is richer than day 1.

- **Hands-off documentation** — every `/save` is a structured journal entry: what was built, what was decided, what's still open. Over a long engagement this becomes a complete record of the project's evolution without anyone sitting down to write it up.

- **Decisions index** — `DECISIONS.md` grows into a lifecycle-tracked index of the project's architectural decisions, updated at every `/save`. Decisions that are more than 30 days old **and** were restated within the last 14 days are automatically promoted to `docs/adr/` or `STANDING.md`; those unseen for more than 60 days are retired. (A decision that has simply gone quiet without being reversed is retired, not promoted — the 14-day recency condition is what distinguishes the two.)

- **Arcs index** — `ARCS.md` tracks ongoing and completed work arcs. To start tracking an arc, prefix an OPEN item with a kebab-case slug on first appearance: `[auth-refactor] Replace legacy session tokens`. Carry the same slug forward when the item recurs in later sessions. New arcs are opened automatically when a slugged OPEN item first appears; they close when the item moves to DONE. Once any arcs exist, `TIMELINE.md` leads with arc-organized sections (one per work arc, open arcs first) followed by a chronological section for any day files not referenced in any arc — both views coexist in one file. Stale arcs (open more than 60 days, quiet more than 30 days) are surfaced at `/save` time for user confirmation — never auto-closed.

- **Split-history consolidation** — if the same project accumulated history under two different directory names (a rename, dots-vs-hyphens drift, or a session that ran before a remote was set), the historian detects this during `/save` and prompts you to consolidate. It shows both ranges, explains which signals aligned, and proposes a canonical directory. You choose to consolidate, keep them separate, or cancel — nothing merges without confirmation.

- **Backfillable** — already have a project with months of git history but no historian files? BACKFILL reconstructs day files from `git log` so you're not starting from zero. Existing session-saved files are never overwritten. Backfilled files are marked `(backfilled)` in their header — `# my-app — 2025-11-14 (backfilled)` — so they're visually distinguishable from session-saved summaries and treated as lower-confidence reconstructions.

- **History integrity** — if you ask the historian agent to amend a prior summary, it surfaces the request, quotes the contested text, and requires explicit evidence-based justification before touching anything. Requests to soften wording or revise narrative without a demonstrable factual error are declined. This prevents agent-mediated driveby changes. The protection exists so casual revision requests don't slip through unexamined.

---

## What gets stored

History files live at `$HISTORY_ROOT/<project-name>/YYYY-MM-DD.md` (eg. the default for Claude Code is `~/.claude/history`). For sessions with no git repo — stand-alone tasks, exploratory sessions, anything outside a project directory — files go to `$HISTORY_ROOT/.journal/YYYY-MM-DD.md` and the file header uses `journal` as the project label. Each file is a short structured summary with per-section caps (STATE: 2 sentences, DECISIONS: 10 bullets, DONE: 15 bullets, OPEN: 5 bullets):

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

When you have multiple day files, the agent maintains a `TIMELINE.md`. When an `ARCS.md` exists, the timeline leads with arc-organized sections — one section per work arc with a single dated note from the most recent session, open arcs listed first — followed by a chronological section for any day files not referenced in any arc. Both views coexist in one file. Before any arcs have been tracked, the timeline is a chronological day-by-day format only (1-2 bullets per day). Either way it is regenerated from scratch on each `/save` where a new day file was written or arc data changed; otherwise it is left untouched.

The agent also maintains a `DECISIONS.md` — a lifecycle-tracked index of the project's architectural decisions, recording when each first appeared, when it was last restated, and whether it was superseded, graduated to a standing doc, or retired. It is updated automatically at `/save` time.

The agent also maintains an `ARCS.md` — an index of ongoing and completed work arcs. OPEN items that use `[arc-slug]` syntax are tracked here automatically. When an arc closes (its OPEN item moves to DONE), the index records which session and commit closed it. `ARCS.md` is what drives arc-organized `TIMELINE.md` generation once at least one arc exists.

If you run `/save` more than once on the same day, the historian merges rather than overwrites — STATE is updated to the latest session, and DECISIONS/DONE/OPEN are unioned and deduplicated. Running `/save` multiple times a day (and from multiple sessions) is safe.

---

## How sessions connect

When you start a session, the prompt-submit hook fires before your agent sees the message. It reads the most recent history file for the current project, injects only the STATE and OPEN sections as context — silently, automatically — and appends a note pointing to `/load` for the full entry. By the time your agent responds to your first message, it already knows where the project stands.

`/load` is for surfacing context from a past session, not the current one. Run it with a date — `2026-07-28`, `yesterday`, `last week`, `3 days ago` — and it finds that day's history file. If a `TIMELINE.md` exists for the project, it's presented first as a project arc overview; then the day file is shown, labeled as historical context; then a divergence check shows what changed between that snapshot and today. If no file exists for the requested date, it lists what's available instead of silently falling back. If invoked with no date, `/load` explains that the hook already injected current session context and prompts you to specify a date or date range.

Pass two dates to get a narrative across a range — `/load 2026-07-01 2026-07-31`. This delegates to the historian agent, which reads the day files for that span and synthesizes an arc: key decisions, significant work, and what was open at the end of the period. It's an editorial summary, not a concatenation — only what's in the day files, nothing inferred.

If no history file exists for a project at all, use BACKFILL to reconstruct a scaffold from `git log` — branch state, recent commits, and diff stats. This is a cold-start aid, not a real substitute: it can only surface what's in your commit messages. Decisions, reasoning, and open questions that never made it into a commit are invisible to it. Run `/save` at the end of sessions where those things matter.

---

## Costs and tradeoffs

**What's free:** context injection at session start is a local file read — no LLM call, no tokens. The stop hook notification is a shell script. Neither costs anything.

**What costs tokens:** `/save` synthesizes a briefing first, then runs a pre-check. If no tool calls or file changes occurred, it stops without invoking the historian. If DECISIONS and OPEN are both empty after synthesis, it surfaces a choice: full save (synthesized briefing + full index maintenance) or BACKFILL (git-only reconstruction, no synthesis, no index updates). BACKFILL is cheaper and sufficient when there are no decisions or open items to capture — the agent waits for an explicit selection rather than deciding automatically.

**`/save` is optional.** Run it when decisions were made, when something was learned that git can't capture, or when the session was long enough that re-establishing context manually would be painful. For pure implementation sessions where everything is in the commits, BACKFILL at the next session start is usually sufficient.

**What git log can't do.** Git log reconstruction gives you orientation — branch, recent commits, what changed. It cannot give you context: why a decision was made, what was tried and abandoned, what's still open. Those only exist in the conversation. If your commit messages captured all of that, your git history would be bloated and unusual. `/save` is the right place for it.

---

## Bibliography

Nothing in the core workflow depends on this. It's optional if you don't care about source tracking.

The historian builds a bibliography of external sources consulted during a session. The pipeline has three parts:

1. **Any external read** emits a `CITE:` tag — the researcher agent emits one after every source block, and the main agent emits one whenever it uses a web fetch or search tool directly:

   ```
   CITE: slug=<kebab-slug> url=<url-or-path> accessed=<YYYY-MM-DD>
   ```

   The slug is kebab-case for the resource (not the question). The same document cited twice uses the same slug.

2. When a finding drives a decision, the main agent emits a `DECISION-SOURCE:` marker **immediately in the same response**:

   ```
   DECISION-SOURCE: slug=<slug>
   ```

   The distinction matters: `CITE:` is a paper trail of everything consulted; `DECISION-SOURCE:` marks what actually drove a choice. A session with many `CITE:` tags and few `DECISION-SOURCE:` markers is normal — it means a lot was looked up but only some of it was load-bearing.

3. At `/save` time, the historian scans the session transcript for both tags and upserts entries into `BIBLIOGRAPHY.md` at the repo root. For journal sessions (no git repo), `BIBLIOGRAPHY.md` is written to `$HISTORY_ROOT/.journal/BIBLIOGRAPHY.md` instead. `CITE:` tags without a matching `DECISION-SOURCE:` still appear in the bibliography — they contribute to the reconstruction record even if they didn't explicitly drive a decision.

This step is **graceful** — if no tags are found in a session, the historian reports "Bibliography: skipped (no CITE tags this session)" and moves on. Nothing breaks if you don't use it.

`BIBLIOGRAPHY.md` entries look like this:

```markdown
### stripe-idempotency-keys

- **Source:** https://stripe.com/docs/api/idempotent_requests
- **Accessed:** 2025-11-14
- **Decision:** Use idempotency keys on all charge attempts to prevent double-charges on retry
- **Sessions:** 2025-11-14, 2025-11-21
```

---

> **Note:** The installer appends routing rules (historian, researcher, and bibliography conventions) to your harness's project instructions file automatically. For manual install steps, see your adapter's README.

## Repository structure

```
context-historian/
├── skills/               ← agent-neutral skill definitions (the brain)
│   ├── historian/        ← SAVE, LOAD RANGE, BACKFILL procedures
│   └── researcher/       ← documentation lookup procedures
├── scripts/              ← shared shell helpers
│   ├── resolve-project.sh
│   └── latest-day-file.sh
├── adapters/             ← per-harness connectors (the nervous system)
│   ├── claude-code/      ← reference implementation
│   │   ├── agents/       ← Claude Code agent definitions with frontmatter
│   │   ├── commands/     ← /load, /save, /team-sync slash commands
│   │   └── hooks/        ← SessionStart, UserPromptSubmit, Stop hooks
│   └── README.md         ← adapter contract for building new adapters
└── CLAUDE.md             ← Claude Code routing rules (appended to ~/.claude/CLAUDE.md)
```

**Existing Claude Code users see no change** — `install.sh` installs the same files to the same paths in `~/.claude/`. The `skills/` and `adapters/` layout is an internal restructure that separates the brain (harness-agnostic procedures) from the nervous system (Claude Code wiring); the install target is unchanged.

To build an adapter for a different harness, start with `adapters/README.md`.

## Installation

For the **Claude Code adapter** (reference implementation) — see [`adapters/claude-code/README.md`](adapters/claude-code/README.md).

For other harnesses — see [`adapters/README.md`](adapters/README.md) for the adapter contract.

---

## Usage

### Automatic (no action required)

History is injected at the start of every session. The stop hook watches transcript size and notifies you when a manual `/save` is worth running. For short sessions where no lasting decisions were made, git log reconstruction at the next session start is usually sufficient. Use BACKFILL to cold-start a project that has no saved summaries yet.

### `/save` — save the current session manually

Run `/save` before `/clear` or at the end of a substantial session. The historian agent reads the conversation and git state, distills a structured summary, and writes the day file. This captures decisions and context that git log alone can't reconstruct.

### `/team-sync` — see what teammates have landed

Run `/team-sync` to write per-day team activity files for commits other authors have landed on `main` since your last saved session. One file per commit date, raw commit subjects grouped by author — no synthesis. File overlaps with your own changes are flagged with `[!]` in the presented index so you can spot areas where your work and a teammate's may collide.

Team files are written to `$HISTORY_ROOT/<project>/team/` by the historian agent and cross-referenced at next `/save`.

Accepts an optional date override: `/team-sync 2026-07-28` to look back from a specific day rather than the last session anchor.

### BACKFILL — reconstruct history from git

If you're starting with a project that has no history files, the historian agent can reconstruct day files from `git log`.

Open your agent in any directory and ask in plain English:

> "Backfill history for my projects under ~/code"

The historian agent will find all git repos under the path you name, default to the past day as the start (override with a date or "N days ago" expression), write a day file for each active day, and synthesize `TIMELINE.md` for each project.

The agent defaults to `$HOME` as the base directory — narrow it for speed. Existing session-saved files are never overwritten.

BACKFILL writes day files and `TIMELINE.md` only — it does not populate `DECISIONS.md` or `ARCS.md`. Those indexes start building from your first real `/save`.

---

## Platform notes (Claude Code adapter)

- **Notifications** — the stop hook fires a notification when the session transcript exceeds 200KB. On macOS this uses `osascript`; on Linux desktop it falls back to `notify-send` (`apt install libnotify-bin` / `dnf install libnotify`). Windows and headless environments get no notification — the hook silently skips.
- **Date compatibility** — BACKFILL defaults to commits from the past day (yesterday onward). When passing a date range override, both BSD (`date -v-Nd`) and GNU (`date -d "N days ago"`) syntax are accepted; the agent picks whichever works on the current platform.
- **Dependencies** — `bash`, `git`, `jq`. `bash` and `git` are standard everywhere; `jq` must be installed separately on most Linux distros (`apt install jq` or `brew install jq` on macOS if not present).
- **bash version** — `install.sh` uses `[[ ]]` conditionals that require bash 4+. macOS ships bash 3.2 by default, which will cause the installer to fail — install a current bash via Homebrew (`brew install bash`) before running anything on macOS.
