---
description: Add a note or idea to another project's history. The historian decides how to incorporate it (OPEN item, DECISION, general note, etc.).
---

Usage: `/note-for <project-name> <note text>`

## Step 1 — Parse arguments

The first word of the arguments is the project name. Everything after it is the note text.

If either is missing, tell the user the expected usage and stop.

## Step 2 — Find the target history file

List `.md` files (excluding `TIMELINE.md`) in `~/.claude/history/<project-name>/`. Sort by filename date descending and take the most recent.

If the directory does not exist or contains no `.md` files, tell the user no history exists for that project yet and stop.

## Step 3 — Delegate to the historian

Spawn the historian agent with the following information:

- Project name
- Path to the most recent history file
- The note text verbatim
- Instruction: incorporate the note into the history file as appropriate — the historian should decide the right section (OPEN, DECISIONS, or a general note) based on the content. Do not change anything else in the file.

Report back to the user what section the historian placed the note in and confirm the file was updated.
