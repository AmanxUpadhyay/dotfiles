---
description: Daily observability digest for the Claude Code hook + MCP pipeline. Writes a report to the vault.
---

# /hook-health — Daily hook + MCP observability digest

Produces a daily digest of hook-fire activity, pipeline health, and vault outputs. Pairs with `hooks-log.sh` (the NDJSON logger wired into every hook): this command reads that log and summarises it.

Designed to be both:
- Invoked on-demand from Claude Code with `/hook-health` (spot-check).
- Scheduled daily at 23:45 via Claude Desktop's Scheduled Tasks (paste the body of this file as the task description; see `## How to schedule` at the bottom).

## Steps

1. **Today's date.** Compute `YYYY-MM-DD` for the Mac's local date.

2. **Read today's NDJSON hook-fire log.** Path: `~/Library/Logs/claude-crons/hooks-fire.log`. Each line is one JSON object (`ts`, `event`, `hook`, `pid`, `extra`).
   - Use `Bash` to `jq -c 'select(.ts | startswith("<TODAY>"))' ~/Library/Logs/claude-crons/hooks-fire.log` to filter today.
   - If the log is missing or empty, note that in the Warnings section and continue with zero counts.

3. **Aggregate counts.**
   - Total fires today.
   - Count grouped by `.event` (Stop, SessionStart, PreToolUse, PostToolUse, etc.).
   - Count grouped by `.hook` (session-stop.sh, pr-gate.sh, …).
   - Top 5 hooks by fire count.
   - Suggestion: one `jq -s` pipeline like `jq -s '[.[] | .hook] | group_by(.) | map({hook:.[0], count:length}) | sort_by(-.count)'`.

4. **Pipeline health.**
   - `claude-mem` worker: `curl -s --max-time 3 http://127.0.0.1:37777/api/health | jq '{status, version, uptime, mcpReady}'`. If it fails, mark worker as DOWN.
   - Obsidian MCP: try `mcp__obsidian__get_vault_stats` (if available) to verify reachability. If you can't invoke it, note "MCP not called — manual check needed".

5. **Vault outputs for today.**
   - Session-note count: `ls ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/GODL1KE/06-Sessions/*/$(date +%Y-%m-%d)*.md 2>/dev/null | wc -l`
   - Bug-Jar entries: `ls ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/GODL1KE/04-Knowledge/Bug-Jar/$(date +%Y-%m-%d)*.md 2>/dev/null | wc -l`
   - Checkpoints recorded: count `## Checkpoints` occurrences across today's session notes.

6. **Determine overall status.** `OK` / `WARN` / `FAIL`:
   - `FAIL` if: claude-mem worker DOWN, or zero fires today while Claude Code was used (check with session-note count > 0).
   - `WARN` if: ≥50 hook fires today AND 0 session notes (pipeline disconnect) • OR any single hook has > 500 fires (possible loop).
   - Otherwise `OK`.

7. **Write the report** via `mcp__obsidian__write_note` to `99-Logs/YYYY-MM-DD-hook-health.md`. If the `99-Logs/` folder doesn't exist, create it first (MCP should handle this; fall back to `Write` tool if not).

   Use this structure:

```markdown
---
date: YYYY-MM-DD
type: hook-health
status: OK | WARN | FAIL
tags: [health, observability]
---

Part of [[VAULT]]

## Summary

<One sentence: status + headline metric (e.g. "OK — 423 hook fires today, 2 session notes, claude-mem worker up 12h").>

## Hook fires today

| Event | Count |
|---|---|
| Stop | … |
| SessionStart | … |
| PreToolUse | … |
| … | … |

**Total:** N fires across M hooks.

### Top hooks

| Hook | Count |
|---|---|
| session-stop.sh | … |
| auto-format.sh | … |
| … | … |

## Pipeline health

- **claude-mem worker**: UP / DOWN — version `X.Y.Z`, uptime `Xh`, mcpReady: `true`.
- **Obsidian MCP**: reachable / unreachable.
- **NDJSON log**: ok / missing / truncated.

## Vault outputs

- Session notes today: N (paths listed below)
- Bug-Jar entries today: N
- Checkpoints recorded: N

## Warnings

<Any anomalies. If none: "None.">

## Raw counts

<Compact output of the aggregation for spot-checks; keep under 20 lines.>
```

8. **Report back** to the invoker: "Wrote 99-Logs/YYYY-MM-DD-hook-health.md. Status: OK/WARN/FAIL. N fires logged."

## Rules

- Never fabricate numbers. If `jq` fails or the log is missing, write "unavailable" in that row rather than a zero that looks like real data.
- Always produce a report, even in WARN/FAIL — absence of a report would itself be a symptom.
- Keep the report under ~500 words. This is a daily digest, not a full diagnostic.

## How to schedule (Claude Desktop)

1. Open Claude Desktop → Scheduled Tasks → "New task".
2. Name: **Hook Health**.
3. Description: paste this entire file content (or at least the `## Steps` through `## Rules` sections).
4. Schedule: **Every day at 23:45**. Enable "Keep awake" if not already.
5. First run: test by running the task immediately; confirm a file appears at `99-Logs/YYYY-MM-DD-hook-health.md`.
