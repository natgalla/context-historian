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

HISTORY_ROOT="$HOME/.claude/history"

PROJECT_NAME=$(bash "$(dirname "$0")/../scripts/resolve-project.sh")

# Use project subdirectory when in a git repo; .journal fallback for non-git sessions
if [ -n "$PROJECT_NAME" ]; then
  HISTORY_DIR="$HISTORY_ROOT/$PROJECT_NAME"
else
  HISTORY_DIR="$HISTORY_ROOT/.journal"
fi

HISTORY_FILE=$(bash "$(dirname "$0")/../scripts/latest-day-file.sh" "$HISTORY_ROOT" "${PROJECT_NAME:-.journal}")
[ -f "$HISTORY_FILE" ] || exit 0

# Always inject only STATE and OPEN — full history is available via /load or by reading the file directly.
STATE_SECTION=$(awk '/^\*\*STATE\*\*/{found=1} found && /^\*\*[A-Z]/ && !/^\*\*STATE\*\*/{exit} found{print}' "$HISTORY_FILE")
OPEN_SECTION=$(awk '/^\*\*OPEN\*\*/{found=1} found && /^\*\*[A-Z]/ && !/^\*\*OPEN\*\*/{exit} found{print}' "$HISTORY_FILE")
HISTORY_CONTENT="${STATE_SECTION}

${OPEN_SECTION}

Full session history: ${HISTORY_FILE} — run /load for complete context."

jq -n --arg ctx "$HISTORY_CONTENT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
