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

## Step 3b — Gather Today's Meetings

Use `mcp__granola__list_meetings` with `time_range: "this_week"` to find meetings.
Filter to meetings from today's date.

For each meeting found:
1. Determine the org folder using this mapping (match on meeting title or attendee email domain):
   - LXS keywords (lxs, loandex) → `01-LXS/meetings/`
   - Persimmon keywords (persimmon, strategic land, charles church) → `01-LXS/Persimmon Homes/meetings/`
   - AdTecher/Grove keywords (adtecher, grove) → `02-Startups/AdTecher/meetings/`
   - Ledgx keywords (ledgx) → `02-Startups/Ledgx/meetings/`
   - ClubRevAI keywords (clubrevai, club rev) → `03-Clients/ClubRevAI/meetings/`
   - Wayv keywords (wayv, telcom) → `03-Clients/Wayv Telcom/meetings/`
   - Unknown or personal → `00-Inbox/`
2. Check if meeting note already exists: `mcp__obsidian__read_note` with path `<org-meetings-folder>/YYYY-MM-DD-<title-kebab-slug>.md`
3. If note exists, skip (prevents duplicates)
4. If no note exists, use `mcp__granola__get_meetings` to fetch full details, then create via `mcp__obsidian__write_note`:
   - Path: `<org-meetings-folder>/YYYY-MM-DD-<title-kebab-slug>.md`
   - Frontmatter: `date`, `org`, `attendees`, `type: meeting`, `tags: [meeting, <org-lowercase>]`
   - Body: `Part of [[<org-wikilink>]] · [[VAULT]]`, then `## Agenda`, `## Notes`, `## Action Items`, `## Decisions Made`

## Step 4 — Create or Patch

**If today's note exists:**
1. Read it with `mcp__obsidian__read_note`
2. Parse the `## Sessions` section to find already-listed session paths
3. Identify sessions from Step 3 NOT already listed
4. If new sessions exist, use `mcp__obsidian__patch_note` to append them to `## Sessions`
5. Parse the `## Meetings` section — if it says "- No meetings" or is empty, and meetings were found in Step 3b:
   - Replace with wikilinks: `- HH:MM [[path/to/meeting-note|Meeting Title]] (Org) — one-line takeaway`
6. Update `## Tomorrow's Focus` with any new open threads from new sessions or action items from meetings

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

- HH:MM [[path/to/meeting-note|Meeting Title]] (Org) — one-line takeaway
{{- if no meetings from Step 3b: "- No meetings" }}

## Tomorrow's Focus

- [ ] Item from open threads
```

## Output

Confirm what was created or patched, listing the sessions added.
