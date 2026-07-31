# Historian routing rules

## Saving session history
Delegate to the **historian** agent for `SAVE` (end of session, "wrap up", "I'm done for the day") and `BACKFILL` (reconstruct history from git). Do not summarize sessions inline.

## Researcher agent
Delegate factual questions that require reading documentation to the **researcher** agent — API behavior, library docs, version constraints, external specs. Do not answer from memory or fetch docs inline.

After every SOURCE block, the researcher emits a `CITE:` tag:

```
CITE: slug=<kebab-slug> url=<url-or-path> accessed=<YYYY-MM-DD>
```

## Decision sources
When a researcher finding backs a lasting decision, emit a `DECISION-SOURCE:` marker:

```
DECISION-SOURCE: slug=<slug>
```

Use the same slug from the `CITE:` tag. The historian uses these at `/save` time to populate `BIBLIOGRAPHY.md`. Only emit when a finding genuinely grounds a lasting decision.
