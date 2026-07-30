# Historian routing rules

## Loading session history
Use `/load` at the start of a session to surface the last summary. It reads the saved history file directly and only falls back to the historian agent when no file exists. Do not spawn the historian agent for LOAD.

## Saving session history
Delegate to the **historian** agent for `SAVE` (end of session, "wrap up", "I'm done for the day") and `BACKFILL` (reconstruct history from git) only. Do not summarize sessions inline — the agent exists to absorb that work out of main context.

## Using the researcher agent

Delegate factual questions that require reading documentation to the **researcher** agent — API behavior, library docs, version constraints, external specs, project ADRs. Do not answer from memory or fetch docs inline.

After every SOURCE block, the researcher emits a `CITE:` tag:

```
CITE: slug=<kebab-slug> url=<url-or-path> accessed=<YYYY-MM-DD>
```

## Recording decision sources

When a researcher finding backs a lasting decision, emit a `DECISION-SOURCE:` marker on its own line in your response:

```
DECISION-SOURCE: slug=<slug>
```

Use the same slug from the researcher's `CITE:` tag. The historian uses these markers at `/save` time to populate `BIBLIOGRAPHY.md` in the project repo. Only emit for findings that genuinely grounded a lasting decision — not every researcher lookup.
