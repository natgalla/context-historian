#!/usr/bin/env bash
set -euo pipefail

DEST="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$DEST/backups/context-historian-$(date +%Y%m%d-%H%M%S)"

echo "context-historian installer"
echo "Source: $SCRIPT_DIR"
echo "Destination: $DEST"
echo ""
echo "This script will:"
echo "  - Back up any existing CLAUDE.md, commands/load.md, commands/save.md,"
echo "    agents/historian.md, and hooks/ to $BACKUP_DIR"
echo "  - Install the historian agent, /load and /save commands, and three hooks"
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
[[ -f "$DEST/agents/historian.md" ]]        && cp "$DEST/agents/historian.md"        "$BACKUP_DIR/historian.md"
[[ -d "$DEST/hooks" ]]                      && cp -r "$DEST/hooks"                   "$BACKUP_DIR/hooks"
echo "Backups written to $BACKUP_DIR"
echo ""

# Install agent and commands
mkdir -p "$DEST/agents" "$DEST/commands"
cp "$SCRIPT_DIR/agents/historian.md"   "$DEST/agents/historian.md"
cp "$SCRIPT_DIR/commands/load.md"      "$DEST/commands/load.md"
cp "$SCRIPT_DIR/commands/save.md"      "$DEST/commands/save.md"
echo "Installed historian agent and /load, /save commands"

# Install hooks
mkdir -p "$DEST/hooks"
cp "$SCRIPT_DIR/hooks/"*.sh "$DEST/hooks/"
chmod +x "$DEST/hooks/"*.sh
echo "Installed 3 hooks"

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
