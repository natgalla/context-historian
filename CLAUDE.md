# Historian routing rules

## Loading session history
Use `/load` at the start of a session to surface the last summary. It reads the saved history file directly and only falls back to the historian agent when no file exists. Do not spawn the historian agent for LOAD.

## Saving session history
Delegate to the **historian** agent for `SAVE` (end of session, "wrap up", "I'm done for the day") and `BACKFILL` (reconstruct history from git) only. Do not summarize sessions inline — the agent exists to absorb that work out of main context.
