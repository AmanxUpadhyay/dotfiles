---
description: Append a timestamped checkpoint bullet to today's session note (mid-session marker).
---

# /checkpoint — User-triggered session checkpoint

Capture a significant mid-session moment by appending a dated bullet to today's session note under `## Checkpoints`.

## What the user wants

The user has typed `/checkpoint <description>`. The `$ARGUMENTS` value contains the text they want recorded. This is a manual counterpart to the automatic smart-checkpoint.sh hook — both append to the same `## Checkpoints` section.

## Steps

1. **Detect the org** from the current working directory (same mapping as `/session-note`):
   - `vulcan` or `adtecher` → `AdTecher`
   - `ledgx` → `Ledgx`
   - `clubrevai` or `clubrev` → `ClubRevAI`
   - `wayv` → `Wayv`
   - `persimmon` → `Persimmon`
   - `/lxs` (path) → `LXS`
   - Default → `Personal`

2. **Today's session note path**: `06-Sessions/<org>/YYYY-MM-DD-<slug>.md`
   - If you've already written a session note earlier this turn or session, reuse the same slug.
   - If not, pick a 2-5 word kebab-case slug describing the session's current focus.

3. **Read the note** (if it exists) via `mcp__obsidian__read_note` or `Read`.

4. **Find or create the `## Checkpoints` section.** If the note doesn't have one yet, add it just before `## Files changed` (or at end if `## Files changed` is missing).

5. **Append a bullet** with:
   - Format: `- **HH:MM:SS** — <user text from $ARGUMENTS>`
   - Time is current local time.

6. **Write it back** via `mcp__obsidian__patch_note` (append-mode) or `mcp__obsidian__write_note`, or via `Write` as fallback.

7. **Report** to the user: "Checkpoint added to `06-Sessions/<org>/<date>-<slug>.md` at HH:MM:SS."

## Rules

- NEVER overwrite existing session-note content; always append/patch.
- If `$ARGUMENTS` is empty, ask the user what to record instead of creating an empty bullet.
- Do not create a new session note if none exists — complain that there's no session note yet and suggest running `/session-note` first (or let session-stop.sh generate one at turn-end).
- Keep the bullet terse (one line, max ~120 chars). Longer context goes in `## What was done` via `/session-note`.
