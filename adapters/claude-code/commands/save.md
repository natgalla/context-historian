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

**OPEN** — Unresolved items; omit if empty. Arc slug syntax: `[arc-slug] <description>`. Max 5.

Omit any section with nothing to add.

## Spawn

Pass the synthesized briefing to the historian agent as the spawn prompt, prefixed with `SAVE. Working directory: <cwd>.` The historian will use it as the primary session record, run git checks to verify, and handle all index management (DECISIONS.md, ARCS.md, TIMELINE.md, bibliography).
