# Historian routing rules

## Saving session history
For `SAVE` (end of session, "wrap up", "I'm done for the day"), invoke the `/save` skill — it pre-checks whether anything was recorded before delegating to the historian agent. Do not summarize sessions inline.

Delegate to the **historian** agent directly for `BACKFILL` (reconstruct history from git).

## Loading session history
`/load` with a **single date** is handled by the load.md command directly — it locates the day file, presents it, and runs a git divergence check. Do not delegate single-date loads to the historian agent.

`/load` with a **date range** delegates to the historian agent in LOAD RANGE mode.

If `/load` is invoked with no arguments, explain that the prompt-submit hook already injected current session context and ask which date (or date range) the user wants.

## Team sync
`/team-sync` is handled by the team-sync command. The historian agent is invoked only for the final file write (TEAM-FILE mode) — the command owns collection and composition. Do not spawn the full SAVE pipeline for team-sync calls.

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

## Session-opening questions
When responding to session-opening questions ("what's next?", "where did we leave off?", "catch me up"), the prompt-submit hook has already injected project context — answer directly using it. Do not narrate a state check or re-read history files as a ritual before answering.
