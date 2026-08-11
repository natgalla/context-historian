#!/usr/bin/env bash
# Layout (as of phase 1 harness-agnostic restructure):
#   skills/historian/SKILL.md, skills/researcher/SKILL.md  — agent-neutral skill definitions
#   scripts/                                                — shared helper scripts
#   adapters/claude-code/agents/                           — Claude Code agent definitions (installed to ~/.claude/agents/)
#   adapters/claude-code/commands/                         — slash commands (installed to ~/.claude/commands/)
#   adapters/claude-code/hooks/                            — session hooks (installed to ~/.claude/hooks/)
#   CLAUDE.md                                              — routing rules (appended to ~/.claude/CLAUDE.md)
#
# This installer targets the Claude Code adapter. For other adapters see adapters/README.md.
# Phase 2 will extend this script to install skills/ and scripts/ to their own target paths.
set -euo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "error: bash 4+ required (found $BASH_VERSION)"
  echo "  macOS: brew install bash"
  exit 1
fi

DEST="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$DEST/backups/context-historian-$(date +%Y%m%d-%H%M%S)"

echo "context-historian installer"
echo "Source: $SCRIPT_DIR"
echo "Destination: $DEST"
echo ""
echo "This script will:"
echo "  - Back up any existing CLAUDE.md, commands/load.md, commands/save.md,"
echo "    commands/team-sync.md, agents/historian.md, agents/researcher.md, and hooks/ to $BACKUP_DIR"
echo "  - Install the historian agent, /load, /save, and /team-sync commands, and three hooks"
echo "  - Merge CLAUDE.md routing rules into your existing $DEST/CLAUDE.md"
echo "    (appends if the file exists; creates it if not)"
echo ""
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
echo ""

# Backup
mkdir -p "$BACKUP_DIR"
[[ -f "$DEST/CLAUDE.md" ]]                  && cp "$DEST/CLAUDE.md"                  "$BACKUP_DIR/CLAUDE.md"
[[ -f "$DEST/commands/load.md" ]]           && cp "$DEST/commands/load.md"           "$BACKUP_DIR/load.md"
[[ -f "$DEST/commands/save.md" ]]           && cp "$DEST/commands/save.md"           "$BACKUP_DIR/save.md"
[[ -f "$DEST/commands/team-sync.md" ]]      && cp "$DEST/commands/team-sync.md"      "$BACKUP_DIR/team-sync.md"
[[ -f "$DEST/agents/historian.md" ]]        && cp "$DEST/agents/historian.md"         "$BACKUP_DIR/historian.md"
[[ -f "$DEST/agents/researcher.md" ]]      && cp "$DEST/agents/researcher.md"        "$BACKUP_DIR/researcher.md"
[[ -d "$DEST/hooks" ]]                      && cp -r "$DEST/hooks"                   "$BACKUP_DIR/hooks"
[[ -f "$DEST/settings.json" ]]              && cp "$DEST/settings.json"              "$BACKUP_DIR/settings.json"
echo "Backups written to $BACKUP_DIR"
echo "IMPORTANT: settings.json was backed up but NOT modified. Merge the hooks block shown below manually — copy-pasting over an existing file will lose your current config."
echo ""

# Install agent and commands (from claude-code adapter)
mkdir -p "$DEST/agents" "$DEST/commands"
cp "$SCRIPT_DIR/adapters/claude-code/agents/historian.md"   "$DEST/agents/historian.md"
cp "$SCRIPT_DIR/adapters/claude-code/agents/researcher.md"  "$DEST/agents/researcher.md"
cp "$SCRIPT_DIR/adapters/claude-code/commands/load.md"       "$DEST/commands/load.md"
cp "$SCRIPT_DIR/adapters/claude-code/commands/save.md"       "$DEST/commands/save.md"
cp "$SCRIPT_DIR/adapters/claude-code/commands/team-sync.md"  "$DEST/commands/team-sync.md"
echo "Installed historian and researcher agents and /load, /save, /team-sync commands"

# Install shared helper scripts
mkdir -p "$DEST/scripts"
cp "$SCRIPT_DIR/scripts/"*.sh "$DEST/scripts/"
chmod +x "$DEST/scripts/"*.sh
echo "Installed shared scripts to $DEST/scripts/"

# Install hooks (from claude-code adapter)
mkdir -p "$DEST/hooks"
cp "$SCRIPT_DIR/adapters/claude-code/hooks/"*.sh "$DEST/hooks/"
chmod +x "$DEST/hooks/"*.sh
hook_count=$(ls "$SCRIPT_DIR/adapters/claude-code/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "Installed $hook_count hooks"

# Merge CLAUDE.md routing rules
if [[ -f "$DEST/CLAUDE.md" ]]; then
  if grep -q "Historian routing rules" "$DEST/CLAUDE.md" 2>/dev/null; then
    echo "CLAUDE.md already contains historian routing rules — skipped"
  else
    echo "" >> "$DEST/CLAUDE.md"
    cat "$SCRIPT_DIR/CLAUDE.md" >> "$DEST/CLAUDE.md"
    echo "Appended historian routing rules to existing CLAUDE.md"
  fi
else
  cp "$SCRIPT_DIR/CLAUDE.md" "$DEST/CLAUDE.md"
  echo "Created CLAUDE.md with historian routing rules"
fi

echo ""
echo "Done. Add the following to ~/.claude/settings.json to wire up the hooks,"
echo "then restart Claude Code:"
echo ""
cat <<'EOF'
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
EOF
