#!/usr/bin/env bash
# Usage: latest-day-file.sh <history-root> <project-slug>
# Stdout: path to the newest YYYY-MM-DD.md, or empty if none found.
HISTORY_ROOT="${1:-$HOME/.claude/history}"
PROJECT_SLUG="$2"
DIR="$HISTORY_ROOT/$PROJECT_SLUG"
[ -d "$DIR" ] || exit 0
find "$DIR" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md' | sort | tail -1
