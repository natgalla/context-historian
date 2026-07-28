#!/bin/bash
# Runs on session Stop (including /clear and compact).
# Fires a 300KB notification to prompt a manual /save while context is live.
# If no manual save exists for today, writes a git-based auto-save as a failsafe.
# Auto-saved files are marked <!-- AUTO-SAVED --> so they can be overwritten by subsequent
# auto-saves (e.g. after a /clear mid-day) without clobbering a manual save.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Derive project name from git root, fall back to cwd basename
PROJECT_NAME=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null | xargs -I{} basename {})
HOME_BASENAME=$(basename "$HOME")

if [ -n "$PROJECT_NAME" ] && [ "$PROJECT_NAME" != "$HOME_BASENAME" ]; then
  HISTORY_DIR="$HOME/.claude/history/$PROJECT_NAME"
else
  HISTORY_DIR="$HOME/.claude/history"
  PROJECT_NAME=$(basename "$CWD")
fi

TODAY=$(date +%Y-%m-%d)
DAY_FILE="$HISTORY_DIR/$TODAY.md"

# Fire notification if transcript is large — prompt for manual save while context is live
PROJECT_KEY=$(echo "$CWD" | tr '/' '-')
TRANSCRIPT=$(ls -t "$HOME/.claude/projects/$PROJECT_KEY"/*.jsonl 2>/dev/null | head -1)
if [ -n "$TRANSCRIPT" ]; then
  SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
  if [ "$SIZE" -gt 300000 ]; then
    # macOS only — silently skipped on other platforms
    osascript -e 'display notification "Context is large — run /save before clearing" with title "Claude Code" sound name "Ping"' 2>/dev/null || true
  fi
fi

# Skip auto-save if a manual save exists for today (no AUTO-SAVED marker means it's manual)
if [ -f "$DAY_FILE" ] && ! grep -q '<!-- AUTO-SAVED -->' "$DAY_FILE" 2>/dev/null; then
  exit 0
fi

# Auto-save: build a git-based summary
mkdir -p "$HISTORY_DIR"

# Find last HEAD hash — use previous auto-save or the last manual save
LAST_FILE=$(ls "$HISTORY_DIR"/*.md 2>/dev/null | grep -v TIMELINE | sort | tail -1)
LAST_HEAD=""
if [ -f "$LAST_FILE" ]; then
  LAST_HEAD=$(grep '<!-- HEAD:' "$LAST_FILE" 2>/dev/null | sed 's/.*<!-- HEAD: \([a-f0-9]*\) -->/\1/')
fi

# Get commits since last save
if [ -n "$LAST_HEAD" ]; then
  GIT_LOG=$(git -C "$CWD" log --oneline "${LAST_HEAD}..HEAD" 2>/dev/null)
else
  GIT_LOG=$(git -C "$CWD" log --oneline --since="$(date +%Y-%m-%d)" 2>/dev/null)
fi

CURRENT_HEAD=$(git -C "$CWD" rev-parse HEAD 2>/dev/null)
CURRENT_BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

{
  echo "# $PROJECT_NAME — $TODAY (auto-saved)"
  echo ""
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "**STATE** — Auto-saved at session end. Branch: \`$CURRENT_BRANCH\`. Run /historian to replace with a full context-aware summary."
  else
    echo "**STATE** — Auto-saved at session end (no git). Run /historian to replace with a full context-aware summary."
  fi
  echo ""
  if [ -n "$GIT_LOG" ]; then
    echo "**DONE**"
    while IFS= read -r line; do
      [ -n "$line" ] && echo "- $line"
    done <<< "$GIT_LOG"
    echo ""
  fi
  echo "**OPEN**"
  echo "- Auto-save only — run /historian to capture decisions and full session context."
  if [ -n "$CURRENT_HEAD" ]; then
    echo ""
    echo "<!-- HEAD: $CURRENT_HEAD -->"
  fi
  echo "<!-- AUTO-SAVED -->"
} > "$DAY_FILE"
