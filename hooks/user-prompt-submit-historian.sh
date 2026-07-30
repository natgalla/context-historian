#!/bin/bash
# On the first prompt of a new session, injects the most recent history file
# as additionalContext. The SessionStart hook leaves a sentinel to identify
# first-prompt vs. subsequent prompts.

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

SENTINEL="/tmp/claude-historian-${SESSION_ID}.sentinel"
[ -f "$SENTINEL" ] || exit 0
rm -f "$SENTINEL"

# Derive project name from git root, fall back to cwd basename
PROJECT_NAME=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null | xargs -I{} basename {})
HOME_BASENAME=$(basename "$HOME")

# Use project subdirectory if we have a meaningful name; top-level fallback otherwise
if [ -n "$PROJECT_NAME" ] && [ "$PROJECT_NAME" != "$HOME_BASENAME" ]; then
  HISTORY_DIR="$HOME/.claude/history/$PROJECT_NAME"
else
  HISTORY_DIR="$HOME/.claude/history"
fi

HISTORY_FILE=$(find "$HISTORY_DIR" -maxdepth 1 -name "*.md" ! -name "TIMELINE.md" 2>/dev/null | sort | tail -1)
[ -f "$HISTORY_FILE" ] || exit 0

HISTORY_CONTENT=$(cat "$HISTORY_FILE")

jq -n --arg ctx "$HISTORY_CONTENT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
