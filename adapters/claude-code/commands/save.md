Before spawning the historian, perform a pre-check and then synthesize a briefing.

## Pre-check

Synthesize the briefing first (see below), then evaluate:

- **No tool calls or file changes** — report "Nothing to save — no changes recorded this session" and stop.
- **DECISIONS and OPEN both empty after synthesis** — present a choice and wait for an explicit selection before proceeding:
  - **Full save** — synthesized briefing, full index maintenance (DECISIONS.md, ARCS.md, TIMELINE.md). Higher cost.
  - **BACKFILL** — git-only reconstruction, no synthesis, no index maintenance. Cheaper and sufficient when there are no decisions or open items to capture.

## Briefing synthesis

The historian runs in an isolated context — it receives no parent conversation history. Before spawning, synthesize the session into the four standard sections. Historian Step 3 is the canonical format spec; key constraints for the briefing:

**STATE** — 1-2 sentences: current branch, what's in progress, any broken/blocked state.

**DECISIONS** — `- [HH:MM:SS] <decision> — <why>`. Lasting decisions only; omit micro-decisions. Max 10.

**DONE** — `- [HH:MM:SS] <what changed> (<file or commit ref>)`. Confirmed changes only; no reverted work. Max 15.

**OPEN** — Unresolved items; omit if empty. Arc slug syntax: `[arc-slug] <description>`. Max 5. Do not open arcs for pending CI runs — CI resolves itself and cannot be tracked or closed by the historian.

Omit any section with nothing to add.

## Citations

Before spawning, scan the conversation for any external sources consulted — GitHub PRs, web pages, docs, API responses. For each, emit a `CITE` tag in the briefing:

`CITE: slug=<kebab-slug> url=<url> accessed=<YYYY-MM-DD>`

If a cited source grounded a DECISION, also emit:

`DECISION-SOURCE: slug=<slug>`

If the historian asks whether external sources were consulted, always answer yes if any tool calls fetched external content (GitHub API, web fetch, etc.) and provide the citations. Do not leave the question unanswered.

## Spawn

Pass the synthesized briefing to the historian agent as the spawn prompt, prefixed with `SAVE. Working directory: <cwd>.` The historian will use it as the primary session record, run git checks to verify, and handle all index management (DECISIONS.md, ARCS.md, TIMELINE.md, bibliography).

Do not display the synthesized briefing to the user before spawning — pass it directly to the historian agent without printing it.

## Post-historian: Stale arc resolution

If the historian's output contains a "Stale arcs" line, run the following resolution flow before closing the save. Do not skip this — stale arcs left unresolved accumulate across sessions.

**Step 1 — Extract stale slugs.** Parse each `[arc-slug]` from the historian's stale arc report.

**Step 2 — Read ARCS.md.** Read the project's ARCS.md to retrieve the `summary` for each stale arc.

**Step 3 — Gather evidence for PR arcs.** For any arc whose summary mentions "PR #N", run:

```bash
gh pr view N --repo <remote> --json number,title,state
```

A `MERGED` or `CLOSED` result is sufficient evidence to auto-close. Record the slug, PR state, and title.

**Step 4 — Present for resolution.** Display two groups:

*Auto-closing (evidence-backed):*
- `[slug]` — PR #N merged: "title"

*Needs your verdict — for each, reply: `still active` / `close: <reason>` / `conclude` (not pursuing):*
- `[slug]` — summary

Wait for explicit verdicts on all ambiguous arcs before proceeding. Do not proceed with partial verdicts.

**Step 5 — Spawn historian in CLOSE ARCS mode.** Pass all confirmed closes (evidence-backed + user-confirmed) as the spawn prompt:

```
CLOSE ARCS. Working directory: <cwd>.

<slug> | <closed-by reason>
<slug> | <closed-by reason>
```

The historian writes the closes to ARCS.md. Do not edit ARCS.md directly.
