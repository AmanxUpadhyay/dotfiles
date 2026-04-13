# Session Note

Write a concise, intelligent session note to Obsidian capturing this session's work.

## Instructions

1. **Detect org** from the current working directory using this mapping:
   - `vulcan` or `adtecher` → AdTecher, folder: `AdTecher`
   - `ledgx` → Ledgx, folder: `Ledgx`
   - `clubrevai` or `clubrev` → ClubRevAI, folder: `ClubRevAI`
   - `wayv` → Wayv, folder: `Wayv`
   - `persimmon` → Persimmon, folder: `Persimmon`
   - `/lxs` → LXS, folder: `LXS`
   - Default → Personal, folder: `Personal`

2. **Generate a slug** (2-5 words, kebab-case) describing this session's main focus (e.g., `hook-quality-filter`, `auth-refactor`, `pipeline-e2e-fix`).

3. **Write the note** via `mcp__obsidian__write_note`:
   - Path: `06-Sessions/<folder>/<date>-<slug>.md` (date format: YYYY-MM-DD)
   - If path exists, append time: `<date>-<HHmm>-<slug>.md`

4. **Use this structure**:

```markdown
---
date: <YYYY-MM-DD>
org: <OrgName>
type: session
tags: [session, <org-lowercase>]
---

Part of <wikilink based on org>

## What was done

<Summarize the session's work in 3-5 bullet points. Be specific about what was accomplished, not just what was discussed.>

## Decisions made

<Any architectural or design decisions. "None" if none.>

## Bugs fixed

<List any bugs fixed with brief description. "None" if none.>

## Open threads

<Any unfinished work or follow-up items. "None" if none.>

## Files changed

<List files that were edited/created this session>
```

5. **Org wikilinks**:
   - AdTecher: `[[02-Startups/AdTecher/AdTecher|AdTecher]] · [[VAULT]]`
   - Ledgx: `[[02-Startups/Ledgx/Ledgx|Ledgx]] · [[VAULT]]`
   - ClubRevAI: `[[03-Clients/ClubRevAI/ClubRevAI|ClubRevAI]] · [[VAULT]]`
   - Wayv: `[[03-Clients/Wayv Telcom/Wayv Telcom|Wayv]] · [[VAULT]]`
   - Persimmon: `[[01-LXS/Persimmon Homes/Persimmon Homes|Persimmon]] · [[01-LXS/LXS|LXS]] · [[VAULT]]`
   - LXS: `[[01-LXS/LXS|LXS]] · [[VAULT]]`
   - Personal: `[[VAULT]]`

6. **If bugs were fixed**, also create Bug-Jar entries at `04-Knowledge/Bug-Jar/<date>-<bug-slug>.md` with:
   - Frontmatter: `date`, `org`, `type: bug-fix`, `tags: [bug-jar, <org-lowercase>]`
   - Sections: Bug title, Symptom, Root Cause, Fix, Files Changed
   - Link back to the session note

7. **Report** the created note path when done.

## Rules

- Be concise but specific
- Focus on what was DONE, not what was discussed
- Never create new top-level vault folders
- Skip Bug-Jar if no actual bugs were fixed
