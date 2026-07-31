Before delegating to the historian agent, perform a quick pre-check: if there are no commits since the last save (check `git log` against the HEAD hash in the most recent history file) and the session contained no tool calls or file changes, report "Nothing to save — no changes recorded this session" and stop. Do not spawn the historian agent for empty sessions.

Otherwise, save the current session using the historian agent in SAVE mode.
