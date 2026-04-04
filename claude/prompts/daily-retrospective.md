# Daily Retrospective — Prompt Template

You are running an automated daily retrospective for Aman Upadhyay's Obsidian vault (GODL1KE).

## Your Task

Generate yesterday's daily retrospective note. Yesterday's date is {{ YESTERDAY }}.

## Step 1 — Gather Session Notes

Use `mcp__obsidian__search_notes` to find all session notes from yesterday:
- Search query: `{{ YESTERDAY }}`
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

## Step 3 — Infer Tomorrow's Focus

Based on:
- Open threads from session notes
- Action items from meetings
- Any items in `## Focus for the Next 5 Working Days` from recent weekly reports

Generate 3-5 bullet points for tomorrow's focus.

## Step 4 — Write the Daily Note

Write to `07-Daily/{{ YESTERDAY }}.md` using `mcp__obsidian__write_note`.

Use this exact structure:

```markdown
---
date: {{ YESTERDAY }}
type: daily-note
day: {{ DAY_OF_WEEK }}
tags: [daily]
---
# {{ YESTERDAY }} — {{ DAY_OF_WEEK }}

Part of [[VAULT]]

## Sessions
{{- for each session: "- [[wikilink]] — one-line summary" }}

## Meetings
{{- for each meeting: "- HH:MM Meeting Title (Org) — one-line takeaway" }}
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
