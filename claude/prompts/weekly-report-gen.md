# Weekly Report Generation — Prompt Template (Friday Draft)

You are running automated weekly report generation for Aman Upadhyay's Obsidian vault (GODL1KE).

## Your Task

Generate this week's draft weekly reports. Today is Friday {{ TODAY }}. The week is {{ WEEK }} (Mon {{ MON }} → Fri {{ TODAY }}).

## Org Paths Reference

| Org | Context file | Weekly reports folder |
|---|---|---|
| LXS | `[[01-LXS/LXS]]` | `01-LXS/reports/weekly/` |
| Persimmon | `[[01-LXS/Persimmon Homes/Persimmon Homes]]` | `01-LXS/Persimmon Homes/reports/weekly/` |
| AdTecher | `[[02-Startups/AdTecher/AdTecher]]` | `02-Startups/AdTecher/reports/weekly/` |
| Ledgx | `[[02-Startups/Ledgx/Ledgx]]` | `02-Startups/Ledgx/reports/weekly/` |
| ClubRevAI | `[[03-Clients/ClubRevAI/ClubRevAI]]` | `03-Clients/ClubRevAI/reports/weekly/` |
| Wayv Telcom | `[[03-Clients/Wayv Telcom/Wayv Telcom]]` | `03-Clients/Wayv Telcom/reports/weekly/` |

## Step 1 — Read This Week's Daily Notes

Daily notes use the pattern `07-Daily/YYYY-MM-DD-dayname.md` (e.g., `2026-04-03-friday.md`).

Use `mcp__obsidian__search_notes` to find daily notes from this week (search for each date string: {{ MON }}, {{ TUE }}, {{ WED }}, {{ THU }}, {{ TODAY }}). Alternatively, use `mcp__obsidian__read_note` if you know the exact day name for each date (use Bash: `date -v-Nd +%A | tr '[:upper:]' '[:lower:]'` where N=4,3,2,1,0 days ago).

Skip any that don't exist (no work that day).

## Step 2 — Identify Active Orgs

From the daily notes, identify which orgs had activity this week (sessions or meetings).

## Step 3 — Generate Per-Org Reports

For each active org, generate a weekly report at `<org-reports-folder>/{{ TODAY }}-weekly-<org-slug>.md`.

Org slugs: `lxs`, `persimmon`, `adtecher`, `ledgx`, `clubrevai`, `wayv`

Use this structure:
```markdown
---
date: {{ TODAY }}
org: {{ ORG }}
week: {{ WEEK }}
type: weekly-report
period: friday-draft
tags: [weekly-report, {{ org-slug }}]
---

# Weekly Update — {{ ORG }} — {{ WEEK }} Friday Draft

Part of {{ CONTEXT_WIKILINK }} · [[VAULT]]

## End of Week Recap
Brief 2-3 sentence summary of the week for this org.

## Wins / Progress
- (bullet per win, extracted from daily notes)

## Risks / Concerns
- (bullet per risk/blocker, extracted from open threads)

## Focus for the Next 5 Working Days
- (3-5 bullets from open threads and tomorrow's focus entries)
```

## Step 4 — Generate Combined Summary

Write to `07-Daily/{{ WEEK }}-weekly-summary.md`:

```markdown
---
date: {{ TODAY }}
type: weekly-summary
week: {{ WEEK }}
period: friday-draft
tags: [weekly-summary]
---

# Weekly Summary — {{ WEEK }}

Part of [[VAULT]]

## Cross-Org Highlights
{{- For each active org: "### OrgName (N sessions, M meetings)" with 1-3 bullet wins }}

## Key Decisions This Week
{{- Any ADR wikilinks that appeared across daily notes }}
{{- "- None" if none }}

## Next Week's Priorities (all orgs)
{{- Aggregated from all per-org "Focus for Next 5 Working Days" sections }}
```

## Rules
- Set `period: friday-draft` in all frontmatter — Monday cron will update to `final`
- Only include content from this week's daily notes — no speculation
- Wikilink all ADR references and session notes
- If an org had zero activity this week, skip it entirely
