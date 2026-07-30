#!/bin/bash
# Fires a notification when the session transcript is large — nudging you to run /save
# while context is still live. Does not write any history files itself.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

notify_user() {
  local msg="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    osascript -e "display notification \"$msg\" with title \"Claude Code\" sound name \"Ping\"" 2>/dev/null || true
  elif command -v notify-send &>/dev/null; then
    notify-send "Claude Code" "$msg" 2>/dev/null || true
  fi
}

# Claude Code stores project transcripts at ~/.claude/projects/<key>/ where <key>
# is the CWD with slashes replaced by dashes (an internal convention, not a public API).
# If this path doesn't exist the transcript check is silently skipped — that's intentional.
PROJECT_KEY=$(echo "$CWD" | tr '/' '-')
TRANSCRIPT=$(ls -t "$HOME/.claude/projects/$PROJECT_KEY"/*.jsonl 2>/dev/null | head -1)
if [ -n "$TRANSCRIPT" ]; then
  SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
  if [ "$SIZE" -gt 300000 ]; then
    notify_user "Context is large — run /save before clearing"
  fi
fi
