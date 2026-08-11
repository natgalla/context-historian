#!/usr/bin/env bash
# Resolve git repo → project slug. Stdout: slug or empty string for journal sessions.
PROJECT_NAME=$(git remote get-url origin 2>/dev/null | xargs basename -s .git 2>/dev/null)
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
fi
echo "$PROJECT_NAME"
