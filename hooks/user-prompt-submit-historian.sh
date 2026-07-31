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

HISTORY_FILE=$(ls "$HISTORY_DIR"/*.md 2>/dev/null | grep -v TIMELINE | sort | tail -1)
[ -f "$HISTORY_FILE" ] || exit 0

# Size guard: if file exceeds 3000 characters, inject only STATE and OPEN sections
# to avoid bloating the context window with a large history file.
FILE_SIZE=$(wc -c < "$HISTORY_FILE" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -gt 3000 ]; then
  # Extract STATE section (lines from **STATE** up to the next **SECTION** heading or EOF)
  STATE_SECTION=$(awk '/^\*\*STATE\*\*/{found=1} found && /^\*\*[A-Z]/ && !/^\*\*STATE\*\*/{exit} found{print}' "$HISTORY_FILE")
  # Extract OPEN section (lines from **OPEN** up to the next **SECTION** heading or EOF)
  OPEN_SECTION=$(awk '/^\*\*OPEN\*\*/{found=1} found && /^\*\*[A-Z]/ && !/^\*\*OPEN\*\*/{exit} found{print}' "$HISTORY_FILE")
  HISTORY_CONTENT="${STATE_SECTION}

${OPEN_SECTION}

Full session history available — run /load for complete context."
else
  HISTORY_CONTENT=$(cat "$HISTORY_FILE")
fi

jq -n --arg ctx "$HISTORY_CONTENT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
