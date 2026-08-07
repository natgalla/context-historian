# Historian routing rules

## Saving session history
For `SAVE` (end of session, "wrap up", "I'm done for the day"), invoke the `/save` skill — it pre-checks whether anything was recorded before delegating to the historian agent. Do not summarize sessions inline.

When the historian's SAVE output includes memory graduation candidates (memories eligible for promotion to `~/.claude/CLAUDE.md`), present them to the user, wait for their response, and apply the approved content blocks to `~/.claude/CLAUDE.md`. The historian outputs exactly what to write and where — relay it verbatim and apply after confirmation.

Delegate to the **historian** agent directly for `BACKFILL` (reconstruct history from git).

## Loading session history
`/load` with a **single date** is handled by the load.md command directly — it locates the day file, presents it, and runs a git divergence check. Do not delegate single-date loads to the historian agent.

`/load` with a **date range** delegates to the historian agent in LOAD RANGE mode.

If `/load` is invoked with no arguments, explain that the prompt-submit hook already injected current session context and ask which date (or date range) the user wants.

## Team sync
`/team-sync` is handled by the team-sync command, which collects commits, composes the summary, and writes the team file directly. The historian agent is not invoked. Do not spawn the full SAVE pipeline for team-sync calls.

## Researcher agent
Delegate factual questions that require reading documentation to the **researcher** agent — API behavior, library docs, version constraints, external specs. Do not answer from memory or fetch docs inline.

After every SOURCE block, the researcher emits a `CITE:` tag:

```
CITE: slug=<kebab-slug> url=<url-or-path> accessed=<YYYY-MM-DD>
```

## Citing external sources
Any external read — whether from the researcher agent or a direct WebFetch/WebSearch call — must produce a `CITE:` tag in the response where the result is used. The slug is kebab-case for the resource (not the question); the same document cited twice uses the same slug.

When a finding drives a decision, emit a `DECISION-SOURCE:` marker immediately in the same response:

```
DECISION-SOURCE: slug=<slug>
```

Use the same slug from the `CITE:` tag. Emit at the moment of the decision, not later. The historian collects both tags at `/save` time to populate `BIBLIOGRAPHY.md` — `CITE:` builds the paper trail, `DECISION-SOURCE:` marks what was load-bearing.

## Decisions and arcs indexes
Alongside `TIMELINE.md` and `BIBLIOGRAPHY.md`, the historian maintains two per-project indexes automatically at `/save` time — do not edit any of these files manually. (`TIMELINE.md` is regenerated from scratch on every `/save`; the others are append/upsert updated.)

`DECISIONS.md` — a lifecycle-tracked index of architectural decisions (when each first appeared, was last restated, and whether it was superseded, graduated to a standing doc, or retired).

`ARCS.md` — an index of work arcs: ongoing and completed threads tracked via the `[arc-slug]` syntax in OPEN items. When `ARCS.md` exists, `TIMELINE.md` leads with arc-organized sections followed by a full chronological section — both views coexist in one file. Stale arcs (open >60 days, quiet >30 days) are surfaced in `/save` output for user confirmation — never auto-closed.

## Backfilled history files

Day files reconstructed by BACKFILL are marked with `(backfilled)` in their header (`# project — YYYY-MM-DD (backfilled)`). When one of these is injected or loaded, surface it as a best-effort reconstruction from git history — branch state and commit messages only. Do not present it with the same confidence as a session-saved summary. Context that didn't make it into commit messages (decisions, reasoning, abandoned approaches, open questions) will not appear in it.

## Session-opening questions
When responding to session-opening questions ("what's next?", "where did we leave off?", "catch me up"), the prompt-submit hook has already injected project context — answer directly using it. Do not narrate a state check or re-read history files as a ritual before answering.

## History is read-only
`~/.claude/history/` is never edited directly, under any circumstances. If the user asks to amend or correct a day file, decline and explain: all history writes go through the historian agent, which enforces its own integrity rules. There are no exceptions — not for typos, not for "quick fixes", not for user insistence.

## Project state is not memory
Do not write project status, blockers, or branch state to the auto-memory files (`~/.claude/projects/.../memory/`). Those entries go stale immediately and create a secondary source that contradicts the historian. State lives in the historian day file + current session context. If an auto-memory entry contains project state, delete it.
