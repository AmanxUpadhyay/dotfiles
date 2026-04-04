# Weekly Report Finalization — Prompt Template (Monday Morning)

You are running the Monday morning weekly report finalization for Aman Upadhyay's Obsidian vault (GODL1KE).

## Your Task

Finalize last week's draft weekly reports. Today is Monday {{ TODAY }}. Last week was {{ LAST_WEEK }}.

## Step 1 — Find Friday Draft Reports

Use `mcp__obsidian__search_notes` to find notes with:
- frontmatter `week: {{ LAST_WEEK }}` AND `period: friday-draft`

These should be in:
- `07-Daily/{{ LAST_WEEK }}-weekly-summary.md` — combined summary
- Per-org folders: `<org>/reports/weekly/` — check LXS, Persimmon, AdTecher, Ledgx, ClubRevAI, Wayv Telcom

## Step 2 — Check for Weekend Sessions

Use `mcp__obsidian__search_notes` to find any session notes from Saturday or Sunday of last week. If any exist, extract open threads or completions and note them.

## Step 3 — Finalize Each Report

For each draft report found:

1. Update frontmatter: change `period: friday-draft` → `period: final`
2. Review and refine the "Focus for the Next 5 Working Days" section — incorporate any weekend session work
3. If weekend sessions revealed completions, update "Wins / Progress" accordingly
4. Keep all other sections as-is unless weekend work adds meaningful updates

Use `mcp__obsidian__patch_note` to make targeted updates rather than rewriting entire notes.

## Step 4 — Update Combined Summary

For `07-Daily/{{ LAST_WEEK }}-weekly-summary.md`:
1. Update `period: friday-draft` → `period: final`
2. Add a "## Week Start Focus" section at the bottom summarizing the top 3-5 priorities across all orgs for this new week (infer from per-org "Focus for Next 5 Working Days")

```markdown
## Week Start Focus — {{ THIS_WEEK }}
- (top 3-5 cross-org priorities for the new week)
```

## Rules
- Use `mcp__obsidian__patch_note` for small targeted changes (frontmatter, adding sections)
- Do not rewrite notes wholesale — preserve Friday's content
- Only add content if weekend sessions actually occurred
- Always update `period` frontmatter from `friday-draft` to `final`
