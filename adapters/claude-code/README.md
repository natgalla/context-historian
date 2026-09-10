# Claude Code adapter

This is the reference implementation of context-historian for Claude Code. It wires the shared skills layer into Claude Code via three hooks, two agents, and three slash commands.

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

**Session-opening questions:** after installing, verify your `~/.claude/CLAUDE.md` includes a "Session-opening questions" section (the installer appends it automatically). This tells Claude to answer session-opening questions ("what's next?", "where did we leave off?", "catch me up") directly from the injected context rather than re-reading history files as a ritual. If upgrading from an earlier version, add this manually if it's missing:

```
When responding to session-opening questions ("what's next?", "where did we leave off?", "catch me up"), the prompt-submit hook has already injected project context — answer directly using it. Do not narrate a state check or re-read history files as a ritual before answering.
```

### Manual install

```bash
mkdir -p ~/.claude/agents ~/.claude/commands ~/.claude/hooks ~/.claude/scripts

cp adapters/claude-code/agents/historian.md    ~/.claude/agents/
cp adapters/claude-code/agents/researcher.md   ~/.claude/agents/
cp adapters/claude-code/commands/load.md       ~/.claude/commands/
cp adapters/claude-code/commands/save.md       ~/.claude/commands/
cp adapters/claude-code/commands/team-sync.md  ~/.claude/commands/
cp adapters/claude-code/hooks/*.sh             ~/.claude/hooks/
cp scripts/*.sh                                ~/.claude/scripts/
chmod +x ~/.claude/hooks/*.sh ~/.claude/scripts/*.sh

# Append routing rules to your global ~/.claude/CLAUDE.md (or copy if you don't have one)
cat CLAUDE.md >> ~/.claude/CLAUDE.md
```

Then add the settings.json snippet above.

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
| `commands/team-sync.md` | `/team-sync` slash command — per-day teammate commit log, delegated to historian |
| `hooks/session-start-historian.sh` | SessionStart hook — leaves a sentinel to identify first-prompt sessions |
| `hooks/user-prompt-submit-historian.sh` | UserPromptSubmit hook — injects STATE + OPEN from the most recent day file |
| `hooks/stop-historian.sh` | Stop hook — fires a notification when session transcript grows large |
| `hooks/size-guard.sh` | Shared helper — extracts STATE and OPEN sections from a day file |
