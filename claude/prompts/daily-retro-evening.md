# Daily Retrospective Evening — Prompt Template

You are running an evening update for Aman's Obsidian vault (GODL1KE).

## Your Task

Create or update **today's** daily note.

## Step 1 — Determine Today's Date

Today's date in YYYY-MM-DD format and the day name (lowercase for filename).

## Step 2 — Check if Today's Note Exists

Use `mcp__obsidian__search_notes` to find today's daily note:
- Search query: today's date (YYYY-MM-DD)
- Limit: 5

Look for a result with path starting with `07-Daily/` and containing today's date.

## Step 3 — Gather Today's Sessions

Use `mcp__obsidian__search_notes` to find session notes from today:
- Search query: today's date (YYYY-MM-DD)  
- Limit: 20

Filter results to paths starting with `06-Sessions/`.

## Step 4 — Create or Patch

**If today's note exists:**
1. Read it with `mcp__obsidian__read_note`
2. Parse the `## Sessions` section to find already-listed session paths
3. Identify sessions from Step 3 NOT already listed
4. If new sessions exist, use `mcp__obsidian__patch_note` to append them to `## Sessions`
5. Update `## Tomorrow's Focus` with any new open threads from new sessions

**If today's note does NOT exist:**
1. Create it fresh with `mcp__obsidian__write_note`
2. Use this structure:

```markdown
---
date: YYYY-MM-DD
type: daily
tags: [daily]
---

# YYYY-MM-DD — DayName

Part of [[VAULT]]

## Sessions

- [[06-Sessions/Org/YYYY-MM-DD-slug|Session Title]] — one-line summary

## Meetings

(Skip if no Granola access)

## Tomorrow's Focus

- [ ] Item from open threads
```

## Output

Confirm what was created or patched, listing the sessions added.
