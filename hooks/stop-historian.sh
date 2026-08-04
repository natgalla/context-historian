#!/bin/bash
# Runs on session Stop (including /clear and compact).
# Fires a notification when the transcript exceeds 300KB to prompt a manual /save while context is live.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Derive project name from git remote, fall back to git root basename
PROJECT_NAME=$(git -C "$CWD" remote get-url origin 2>/dev/null | xargs basename -s .git 2>/dev/null)
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
fi

# Use project subdirectory when in a git repo; .journal fallback for non-git sessions
if [ -n "$PROJECT_NAME" ]; then
  HISTORY_DIR="$HOME/.claude/history/$PROJECT_NAME"
else
  HISTORY_DIR="$HOME/.claude/history/.journal"
fi

# Fire notification if transcript is large — prompt for manual save while context is live
PROJECT_KEY=$(echo "$CWD" | tr '/' '-')
TRANSCRIPT=$(ls -t "$HOME/.claude/projects/$PROJECT_KEY"/*.jsonl 2>/dev/null | head -1)
if [ -n "$TRANSCRIPT" ]; then
  SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
  if [ "$SIZE" -gt 300000 ]; then
    osascript -e 'display notification "Context is large — run /save before clearing" with title "Claude Code" sound name "Ping"' 2>/dev/null \
      || notify-send "Claude Code" "Context is large — run /save before clearing" 2>/dev/null \
      || true
  fi
fi
