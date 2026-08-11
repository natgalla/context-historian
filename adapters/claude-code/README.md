# Claude Code adapter

This is the reference implementation of context-historian for Claude Code. It wires the shared skills layer into Claude Code via three hooks, two agents, and three slash commands.

For installation instructions, see the [main README](../../README.md).

---

## How this fits within Claude Code

Claude Code already has several persistence mechanisms — context-historian doesn't replace them, it complements them.

**Built-in memory** tracks who you are: your preferences, role, recurring feedback, things to avoid. It's user-scoped and follows you across every project. context-historian doesn't touch it — and the historian doesn't write project state back into it. Branch state, blockers, and in-flight work belong in the historian day file, not in auto-memory, because that kind of state goes stale immediately and creates a secondary source that contradicts the historian.

**Recommended:** disable Claude Code's auto-memory engine. Claude Code reads from `~/.claude/projects/*/memory/` and injects `MEMORY.md` into every turn automatically — which conflicts with the historian's model of reading memory on demand rather than injecting it wholesale. Adding `"autoMemoryEnabled": false` to `~/.claude/settings.json` turns the engine off entirely, leaving your historian memory files untouched and loaded only when relevant.

**`CLAUDE.md`** holds static project instructions you write and maintain manually — conventions, constraints, architecture notes that don't change session to session. context-historian doesn't replace it; the two complement each other.

**context-historian** tracks where each project stands right now: current branch, decisions made this session, what's open, what's still in flight. It's project-scoped, session-dynamic, and updates automatically as you work.

The short version: built-in memory knows about you, `CLAUDE.md` knows about the project's rules, context-historian knows what happened yesterday.

---

## Adapter contents

| Path | Purpose |
|---|---|
| `agents/historian.md` | Historian agent — Claude Code frontmatter + scope guard + core procedures |
| `agents/researcher.md` | Researcher agent — documentation lookup with `CITE:` emission |
| `commands/load.md` | `/load` slash command — single-date file retrieval and git divergence check |
| `commands/save.md` | `/save` slash command — briefing synthesis + historian delegation |
| `commands/team-sync.md` | `/team-sync` slash command — teammate commit summary |
| `hooks/session-start-historian.sh` | SessionStart hook — leaves a sentinel to identify first-prompt sessions |
| `hooks/user-prompt-submit-historian.sh` | UserPromptSubmit hook — injects STATE + OPEN from the most recent day file |
| `hooks/stop-historian.sh` | Stop hook — fires a notification when session transcript grows large |
| `hooks/size-guard.sh` | Shared helper — extracts STATE and OPEN sections from a day file |
