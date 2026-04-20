# Daily Retrospective — Prompt Template

You are running an automated daily retrospective for Aman Upadhyay's Obsidian vault (GODL1KE).

## Step 0 — Determine Yesterday's Date

Use Bash to compute yesterday's date:
```bash
date -v-1d +%Y-%m-%d        # YESTERDAY (e.g., 2026-04-13)
date -v-1d +%A              # DAY_OF_WEEK (e.g., Sunday)
date -v-1d +%A | tr '[:upper:]' '[:lower:]'  # DAY_NAME_LOWERCASE (e.g., sunday)
```

Store these values mentally and use them throughout. Example: if today is Monday 2026-04-14, then YESTERDAY=2026-04-13, DAY_OF_WEEK=Sunday, DAY_NAME_LOWERCASE=sunday.

## Your Task

Generate yesterday's daily retrospective note using the computed YESTERDAY date.

## Step 1 — Gather Session Notes

Use `mcp__obsidian__search_notes` to find all session notes from yesterday:
- Search query: `YESTERDAY`
- Filter: frontmatter `type: session` or path starts with `06-Sessions/`

For each session found, extract:
- The note's wikilink path (e.g., `06-Sessions/LXS/2026-04-04-graph-naming-overhaul`)
- The `## What was done` section (first sentence only)
- Any ADR wikilinks mentioned (look for `[[` followed by `ADR` or `Decisions/`)
- Any items in `## Open threads`

## Step 2 — Gather Meetings

Use `list_meetings` (Granola MCP) to get meetings from yesterday.
For each meeting, extract:
- Start time (HH:MM format)
- Meeting title
- Which org it belongs to (infer from attendees or title)
- One-line takeaway (from meeting notes or summary)

If `get_meetings` is needed for more detail, use it.

## Step 2b — Create Individual Meeting Notes

For each meeting found in Step 2 that has substantive content (not just a calendar placeholder or a meeting with no notes):
0. For each meeting, call `mcp__granola__get_meeting_transcript` (or `mcp__granola__query_granola_meetings`) to retrieve the full meeting summary, agenda, and action items. Use this full content in step 4 below. If no transcript is available, use the one-line takeaway from Step 2.
1. Determine the org folder using this mapping (match on meeting title or attendee email domain):
   - LXS keywords (lxs, loandex) → `01-LXS/meetings/`
   - Persimmon keywords (persimmon) → `01-LXS/Persimmon Homes/meetings/`
   - AdTecher/Grove keywords (adtecher, grove) → `02-Startups/AdTecher/meetings/`
   - Ledgx keywords (ledgx) → `02-Startups/Ledgx/meetings/`
   - ClubRevAI keywords (clubrevai, club rev) → `03-Clients/ClubRevAI/meetings/`
   - Wayv keywords (wayv, telcom) → `03-Clients/Wayv Telcom/meetings/`
   - Unknown or personal → `00-Inbox/`
2. Attempt to read the expected note path using `mcp__obsidian__read_note` with path `<org-meetings-folder>/YESTERDAY-<title-kebab-slug>.md`. If the read succeeds, the note exists — go to step 3. If it errors (note not found), proceed to step 4.
3. If the read in step 2 succeeded — skip this meeting entirely (prevents duplicates on evening re-runs).
4. If no note exists, create it via `mcp__obsidian__write_note`:
   - Path: `<org-meetings-folder>/YESTERDAY-<title-kebab-slug>.md`
   - If two meetings on the same day resolve to the same slug, append the HH:MM start time to differentiate: `YESTERDAY-HHmm-<title-kebab-slug>.md`.
   - Frontmatter: `date: YESTERDAY`, `org: <org-name>`, `attendees: [<from Granola>]` (if Granola returns no attendees, use `attendees: []`), `type: meeting`, `tags: [meeting, <org-lowercase>]`
   - Body structure:
     ```
     Part of [[<org-wikilink>]] · [[VAULT]]

     ## Agenda
     <from Granola meeting description, or "TBD" if absent>

     ## Notes
     <from Granola summary or transcript>

     ## Action Items
     <from Granola action items, or "- None">

     ## Decisions Made
     <any decisions reached, or "- None">
     ```
5. In the daily note's `## Meetings` section, wikilink to the meeting note:
   `- HH:MM [[<path-to-meeting-note>|Meeting Title]] (Org) — one-line takeaway`
   If running in Patch Mode (evening run) and the daily note already has a `## Meetings` entry for this meeting, leave it unchanged. If the evening run is the first run and the daily note has no `## Meetings` entry yet, use `mcp__obsidian__patch_note` to append the wikilink line to `## Meetings`.

Note: For evening runs (Patch Mode), the duplicate guard in step 3 ensures no meeting note is created twice even if meetings are re-scanned.

## Step 3 — Infer Tomorrow's Focus

Based on:
- Open threads from session notes
- Action items from meetings
- Any items in `## Focus for the Next 5 Working Days` from recent weekly reports

Generate 3-5 bullet points for tomorrow's focus.

## Step 4 — Write the Daily Note

Use Bash to get the lowercase day name for yesterday: `date -v-1d +%A | tr '[:upper:]' '[:lower:]'`

Write to `07-Daily/YESTERDAY-DAY_NAME_LOWERCASE.md` using `mcp__obsidian__write_note`.
Example: `07-Daily/2026-04-03-friday.md`

Use this exact structure:

```markdown
---
date: YESTERDAY
type: daily-note
day: DAY_OF_WEEK
tags: [daily]
---
# YESTERDAY — DAY_OF_WEEK

Part of [[VAULT]]

## Sessions
{{- for each session: "- [[wikilink]] — one-line summary" }}

## Meetings
{{- for each meeting: "- HH:MM [[path/to/meeting-note|Meeting Title]] (Org) — one-line takeaway" }}
{{- if no meetings: "- No meetings" }}

## Decisions
{{- for each ADR found in sessions: "- [[wikilink]] — decision summary" }}
{{- if no decisions: "- None" }}

## Tomorrow's Focus
{{- 3-5 bullet points }}
```

## Rules
- Always use wikilinks for session notes (e.g., `[[06-Sessions/LXS/2026-04-04-graph-naming-overhaul]]`)
- Keep summaries to one line each
- If no sessions from yesterday, write "- No sessions" under Sessions
- Do not include content Aman did not produce or discuss — no speculation
- Frontmatter must have `date`, `type`, `day`, `tags`

## Patch Mode (evening runs only)

If the DATE_HINT starts with "EVENING RUN":
1. Search for an existing note matching today's date using `mcp__obsidian__search_notes`
2. If found, read it with `mcp__obsidian__read_note`
3. Compare `## Sessions` against all sessions found in Step 1 — identify any not yet wikilinked
4. Use `mcp__obsidian__patch_note` to append only the missing sessions to `## Sessions`
5. Refresh `## Tomorrow's Focus` if new open threads were discovered
6. Leave `## Meetings` and `## Decisions` unchanged unless new content was found
7. If no note exists yet, create it fresh following the normal format above
