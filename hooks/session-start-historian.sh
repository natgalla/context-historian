#!/bin/bash
# Writes a sentinel file so the UserPromptSubmit hook knows to inject history
# on the first prompt of this session.
SESSION_ID=$(jq -r '.session_id // empty')
[ -n "$SESSION_ID" ] && touch "/tmp/claude-historian-${SESSION_ID}.sentinel"
true
