# Adapter contract

An adapter is a thin connector between the shared skills layer (`skills/`) and a specific agent harness (Claude Code, OpenAI Agents, LangGraph, etc.). The skills define what the historian and researcher do; adapters define how those skills are wired into a harness.

The reference implementation is `adapters/claude-code/`.

---

## What every adapter must implement

### 1. Session-start injection

On the first prompt of a session, inject the most recent day file for the current project as context. Truncate to STATE and OPEN sections only if the file exceeds 3000 bytes — use `scripts/size-guard.sh` or equivalent logic.

### 2. Command registration

Register these three entry points so users can invoke them by name:

| Command | Behavior |
|---|---|
| `/save` | Synthesize a briefing, then spawn the historian skill in SAVE mode |
| `/load [date\|range]` | Single date: locate and present the day file inline. Date range: delegate to the historian skill in LOAD RANGE mode |
| `/team-sync [date]` | Collect teammate commits and write a team file — historian is not involved |

### 3. Routing rules file

Provide a routing rules file (`CLAUDE.md`, `AGENTS.md`, or harness equivalent) that tells the harness when to delegate to the historian vs. handle inline. At minimum, cover:

- SAVE / BACKFILL → historian skill
- Single-date /load → inline command
- Date-range /load → historian skill (LOAD RANGE mode)
- /team-sync → inline command, no historian
- Documentation lookups → researcher skill

---

## Environment overrides

| Variable | Default | Purpose |
|---|---|---|
| `HISTORY_ROOT` | `~/.claude/history` | Root directory for all history files |
| `RULES_FILE` | harness default | Path to the routing rules file injected at session start |

---

## Injection contract

On the first prompt of a session:

1. Resolve the project slug (`scripts/resolve-project.sh` or equivalent)
2. Find the most recent day file (`scripts/latest-day-file.sh` or equivalent)
3. Apply the size guard (`scripts/size-guard.sh` or equivalent) — full file if ≤3000 bytes; STATE + OPEN only if larger
4. Inject the result as additional context before the harness processes the user's prompt

Each adapter implements this via its harness's event system (hooks, middleware, interceptors, etc.).

---

## Tool capability mapping

Skills declare capabilities rather than tool names. Adapters map native tool names to each capability:

| Capability | Purpose | Claude Code tool |
|---|---|---|
| `shell` | Run git, date, mkdir, find | `Bash` |
| `file-read` | Read day files and index files | `Read` |
| `file-write` | Write day files and index files | `Write` |
| `search` | Grep/glob over history directories | `Grep`, `Glob` |
| `web-fetch` | Fetch external documentation (researcher only) | `WebFetch`, `WebSearch` |

When writing an adapter for a different harness, declare the equivalent native tools for each capability in the adapter's routing rules or agent config.

---

## Reference implementation

`adapters/claude-code/` contains:

- `agents/` — historian and researcher agent definitions with Claude Code frontmatter and scope guard
- `commands/` — `/load`, `/save`, and `/team-sync` slash command definitions
- `hooks/` — three bash hooks wired into Claude Code's SessionStart, UserPromptSubmit, and Stop events
