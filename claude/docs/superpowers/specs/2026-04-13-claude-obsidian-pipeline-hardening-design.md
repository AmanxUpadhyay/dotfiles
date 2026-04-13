# Claude Code + Obsidian Pipeline Hardening

**Date**: 2026-04-13  
**Status**: Approved  
**Author**: Claude (with Aman)

## Problem Statement

The existing Claude Code automation pipeline uses launchd agents that invoke `claude --print` for headless execution. This fails with Max subscription (OAuth) because `--print` requires API authentication. Result: daily and weekly note generation crons fail with "API Error: Unable to connect to API".

### Constraints

- **No API key** — User has Max subscription (OAuth only)
- **Local Obsidian vault** — MCP server runs locally, not accessible from cloud
- **Maintain automation** — Time-triggered note generation, not just session-triggered

## Solution: Desktop Scheduled Tasks

Migrate from launchd + `--print` to Claude Desktop Scheduled Tasks, which:
- Run locally with OAuth session context
- Have access to local MCP servers (including Obsidian)
- Support cron-like scheduling
- Appear as reviewable sessions in the Desktop sidebar

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              Claude Desktop Scheduled Tasks                      │
│              (OAuth-compatible, local MCP access)                │
├─────────────────────────────────────────────────────────────────┤
│  daily-retrospective    │ 09:00 daily    │ Create daily note    │
│  daily-retro-evening    │ 22:30 daily    │ Patch daily note     │
│  weekly-report          │ 17:00 Friday   │ Generate weekly      │
│  weekly-finalize        │ 09:00 Monday   │ Finalize weekly      │
└─────────────────────────────────────────────────────────────────┘
           │
           │ Uses local MCP (obsidian, etc.)
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Obsidian Vault                               │
│       ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/   │
│                           GODL1KE                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Session Hooks (unchanged)                    │
├─────────────────────────────────────────────────────────────────┤
│  SessionStart  → Git context, org detection, last session       │
│  Stop (block)  → Session note prompt                            │
│  SessionEnd    → Breadcrumb writer                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Local LaunchAgents (reduced)                 │
├─────────────────────────────────────────────────────────────────┤
│  healthcheck-preflight  │ 08:50 │ Validate env                  │
│  healthcheck-postrun    │ 11:00 │ Check note presence           │
│  mac-cleanup-scan       │ var   │ Local maintenance             │
│  claude-mem-worker      │ event │ Plugin infrastructure         │
└─────────────────────────────────────────────────────────────────┘
```

## Desktop Scheduled Tasks

### Task 1: daily-retrospective (Morning — Yesterday's Note)

- **Schedule**: 09:00 daily (Europe/London = 08:00 UTC during BST, 09:00 UTC during GMT)
- **Prompt source**: `~/.dotfiles/claude/prompts/daily-retrospective.md`
- **Purpose**: Create **yesterday's** daily note as a retrospective on the previous day
- **Output**: `07-Daily/YYYY-MM-DD-dayname.md` (yesterday's date)
- **Working directory**: `~` (home)
- **Tools**: `mcp__obsidian__*`, Read, Write, Glob, Grep
- **Fallback**: If Granola MCP fails, skip meetings section gracefully

### Task 2: daily-retro-evening (Evening — Today's Note)

- **Schedule**: 22:30 daily (Europe/London = 21:30 UTC during BST, 22:30 UTC during GMT)
- **Prompt source**: `~/.dotfiles/claude/prompts/daily-retro-evening.md` (NEW — to be created)
- **Purpose**: Create or patch **today's** daily note with today's sessions
- **Output**: `07-Daily/YYYY-MM-DD-dayname.md` (today's date)
- **Working directory**: `~` (home)
- **Tools**: `mcp__obsidian__*`
- **Deduplication**: Check session note timestamps; skip any already listed in existing note

### Task 3: weekly-report (Friday Afternoon)

- **Schedule**: 17:00 every Friday (Europe/London = 16:00 UTC during BST, 17:00 UTC during GMT)
- **Prompt source**: `~/.dotfiles/claude/prompts/weekly-report-gen.md`
- **Purpose**: Generate per-org weekly reports from Mon-Fri daily notes
- **Output**: Per-org reports + `07-Daily/YYYY-WNN-weekly-summary.md`
- **Working directory**: `~` (home)
- **Tools**: `mcp__obsidian__*`, Read, Glob, Grep

### Task 4: weekly-finalize (Monday Morning)

- **Schedule**: 09:00 every Monday (Europe/London)
- **Prompt source**: `~/.dotfiles/claude/prompts/weekly-finalize.md`
- **Purpose**: Finalize previous week's report with any weekend sessions
- **Output**: Patches previous week's summary
- **Working directory**: `~` (home)
- **Tools**: `mcp__obsidian__*`

### New Prompt File Required

Create `~/.dotfiles/claude/prompts/daily-retro-evening.md`:

```markdown
# Daily Retrospective Evening — Prompt Template

You are running an evening update for Aman's Obsidian vault (GODL1KE).

## Your Task

Create or update **today's** daily note. Today is {{ TODAY }} ({{ DAY_NAME }}).

## Step 1 — Check if Today's Note Exists

Use `mcp__obsidian__search_notes` to find today's daily note:
- Search query: `{{ TODAY }}`
- Path filter: `07-Daily/`

## Step 2 — Gather Today's Sessions

Use `mcp__obsidian__search_notes` to find session notes from today:
- Search query: `{{ TODAY }}`
- Filter: path starts with `06-Sessions/`

## Step 3 — Create or Patch

**If today's note exists:**
- Read it with `mcp__obsidian__read_note`
- Identify sessions NOT already listed in ## Sessions
- Use `mcp__obsidian__patch_note` to append only new sessions
- Update ## Tomorrow's Focus with any new open threads

**If today's note does NOT exist:**
- Create it fresh using the standard daily note format
- Include all sessions found

## Output Format

Path: `07-Daily/{{ TODAY }}-{{ DAY_NAME_LOWER }}.md`

Use standard daily note structure from the morning template.
```

### Creating Scheduled Tasks

Desktop scheduled tasks are created via the Claude Desktop UI:

1. Open Claude Desktop
2. Open Settings (Cmd+,) → Scheduled Tasks
3. Click "New Task"
4. Configure: name, schedule (cron or natural language), prompt, working directory
5. Set permission mode (recommend: pre-approve tools via "Run now" first)
6. Enable the task

Tasks are stored at `~/.claude/scheduled-tasks/<name>/SKILL.md` and can be edited as plain text after creation.

### Prerequisite

Claude Desktop must be running for scheduled tasks to execute. Add as login item:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Claude.app", hidden:false}'
```

## LaunchAgent Migration

### Retire (archive, don't delete)

| Agent | Reason |
|-------|--------|
| `com.godl1ke.claude.daily-retrospective` | Replaced by Desktop scheduled task |
| `com.godl1ke.claude.daily-retro-evening` | Replaced by Desktop scheduled task |
| `com.godl1ke.claude.weekly-report-gen` | Replaced by Desktop scheduled task |
| `com.godl1ke.claude.weekly-finalize` | Replaced by Desktop scheduled task |

### Keep active

| Agent | Purpose |
|-------|---------|
| `com.godl1ke.claude.healthcheck-preflight` | Validates local env before work day |
| `com.godl1ke.claude.healthcheck-postrun` | Checks automation success |
| `com.godl1ke.claude.mac-cleanup-scan` | Local filesystem maintenance |
| `com.godl1ke.claude-mem-worker` | Plugin infrastructure |

### Archive commands

```bash
# Unload from launchd
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.daily-retrospective.plist
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.daily-retro-evening.plist
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.weekly-report-gen.plist
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.weekly-finalize.plist

# Archive plists
mkdir -p ~/.dotfiles/claude/launchagents/archived/
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.daily-retrospective.plist ~/.dotfiles/claude/launchagents/archived/
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.daily-retro-evening.plist ~/.dotfiles/claude/launchagents/archived/
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.weekly-report-gen.plist ~/.dotfiles/claude/launchagents/archived/
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.weekly-finalize.plist ~/.dotfiles/claude/launchagents/archived/

# Remove symlinks
rm ~/Library/LaunchAgents/com.godl1ke.claude.daily-retrospective.plist
rm ~/Library/LaunchAgents/com.godl1ke.claude.daily-retro-evening.plist
rm ~/Library/LaunchAgents/com.godl1ke.claude.weekly-report-gen.plist
rm ~/Library/LaunchAgents/com.godl1ke.claude.weekly-finalize.plist
```

## Healthcheck Updates

### Preflight phase additions

```bash
# Check Claude Desktop is running
if ! pgrep -x "Claude" >/dev/null; then
  errors+=("Claude Desktop not running — scheduled tasks won't fire")
fi
```

### Postrun phase changes

Replace marker file checks with note presence checks:

```bash
# Check daily note exists (instead of marker file)
TODAY=$(date +%Y-%m-%d)
if ! ls "$OBSIDIAN_VAULT/07-Daily/$TODAY"*.md &>/dev/null; then
  errors+=("Daily note for $TODAY not found")
fi

# Check weekly note exists (Sat/Sun/Mon only)
if [[ "$dow" =~ ^(6|7|1)$ ]]; then
  WEEK=$(date +%Y-W%V)
  if ! ls "$OBSIDIAN_VAULT/07-Daily/$WEEK"*.md &>/dev/null; then
    errors+=("Weekly summary for $WEEK not found")
  fi
fi
```

### Remove stale checks

Remove marker file checks for retired agents:
- `.last-success-daily-retrospective`
- `.last-success-daily-retro-evening`
- `.last-success-weekly-report-gen`
- `.last-success-weekly-finalize`

## Session Hooks

### No changes required

All session hooks work correctly with OAuth:

- **session-start.sh** — Git context, org detection, last session loading, self-healing symlinks
- **session-stop.sh** — Blocking session note prompt (runs inside authenticated session)
- **session-end-note.sh** — No-op placeholder (kept for compatibility)
- **breadcrumb-writer.sh** — Writes repo breadcrumbs

## Testing Plan

### Pre-migration

1. Verify Claude Desktop is running
2. Run healthcheck preflight manually
3. Confirm MCP servers connected (`claude mcp list`)

### Post-migration

1. Create each Desktop scheduled task
2. Run each task manually ("Run now") to verify it works
3. Check Obsidian vault for expected output
4. Wait for scheduled execution and verify
5. Run healthcheck postrun to confirm detection

### Rollback

If issues arise:
1. Re-symlink archived launchd plists
2. Reload agents with `launchctl load`
3. Disable Desktop scheduled tasks

## Success Criteria

- [ ] New prompt file created: `daily-retro-evening.md`
- [ ] All 4 Desktop scheduled tasks created and enabled
- [ ] Yesterday's daily note generated at 09:00 without manual intervention
- [ ] Today's daily note created/patched at 22:30 with today's sessions
- [ ] Weekly report generated Friday 17:00
- [ ] Weekly finalized Monday 09:00
- [ ] Healthcheck detects failures (note missing = alert)
- [ ] Claude Desktop starts on login
- [ ] No duplicate sessions appear in daily notes (dedup works)

## Edge Cases and Mitigations

### Session-Stop vs Evening-Retro Overlap

If a user ends a session at 22:25 (triggering session-stop.sh) and evening-retro runs at 22:30:
- **Mitigation**: Evening-retro checks session note timestamps and skips any already present in the daily note
- **Implementation**: Compare session note paths already in `## Sessions` against search results

### iCloud Sync Delays

The vault is in iCloud (`~/Library/Mobile Documents/`). Sync delays are possible.
- **Mitigation**: Desktop scheduled tasks write locally; iCloud handles sync
- **Risk**: Low — writes are local, not dependent on cloud sync completing

### Granola MCP Authentication

The morning prompt uses Granola for meetings. Auth may fail.
- **Mitigation**: Prompt instructs to skip meetings section gracefully if Granola unavailable
- **Fallback**: Note is created without meetings; can be patched manually

### DST Transitions

Schedules are Europe/London. During DST transitions:
- **BST (Mar-Oct)**: 09:00 local = 08:00 UTC
- **GMT (Oct-Mar)**: 09:00 local = 09:00 UTC
- **Mitigation**: Desktop Scheduled Tasks should handle timezone automatically; verify after first DST transition

## Appendix: Why Not Other Approaches

| Approach | Why rejected |
|----------|--------------|
| API key | User constraint: Max subscription only |
| Remote Triggers | Cannot access local MCP servers |
| Enhanced Stop Hook only | Not time-triggered, session-dependent |
| GitHub-synced vault | Major restructuring, sync complexity |
| AppleScript automation | Fragile, breaks with app updates |
