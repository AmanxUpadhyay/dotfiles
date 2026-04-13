# Pipeline Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate daily/weekly note automation from failing launchd+`--print` to Desktop Scheduled Tasks that work with Max subscription (OAuth).

**Architecture:** Replace 4 launchd agents with 4 Desktop Scheduled Tasks. Update healthcheck to verify note presence instead of marker files. Add Claude Desktop as login item.

**Tech Stack:** Bash, Claude Desktop Scheduled Tasks, Obsidian MCP

---

## File Structure

| Action | Path | Purpose |
|--------|------|---------|
| Create | `~/.dotfiles/claude/prompts/daily-retro-evening.md` | Evening prompt template |
| Modify | `~/.dotfiles/claude/crons/healthcheck.sh` | Add Desktop check, replace marker checks |
| Archive | `~/.dotfiles/claude/launchagents/*.plist` (4 files) | Move retired agents to archived/ |
| Create | `~/.claude/scheduled-tasks/` (4 tasks via UI) | Desktop Scheduled Tasks |

---

## Task 1: Create Evening Prompt Template

**Files:**
- Create: `~/.dotfiles/claude/prompts/daily-retro-evening.md`

- [ ] **Step 1: Create the prompt file**

```bash
cat > ~/.dotfiles/claude/prompts/daily-retro-evening.md << 'PROMPT_EOF'
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
PROMPT_EOF
```

- [ ] **Step 2: Verify file was created**

Run: `head -20 ~/.dotfiles/claude/prompts/daily-retro-evening.md`

Expected: Shows the prompt header and first steps

- [ ] **Step 3: Commit the new prompt**

```bash
cd ~/.dotfiles
git add claude/prompts/daily-retro-evening.md
git commit -m "feat: add evening retrospective prompt template

Creates today's daily note or patches with new sessions.
Supports deduplication by checking existing ## Sessions."
```

---

## Task 2: Update Healthcheck Preflight

**Files:**
- Modify: `~/.dotfiles/claude/crons/healthcheck.sh:31-89` (run_preflight function)

- [ ] **Step 1: Add Claude Desktop check after npx check (around line 48)**

Insert after the `npx` check block, before the `# Vault + config` comment:

```bash
  # Claude Desktop must be running for scheduled tasks
  if ! pgrep -x "Claude" >/dev/null; then
    errors+=("Claude Desktop not running — scheduled tasks won't fire")
  fi
```

- [ ] **Step 2: Add evening prompt to template check (line 60)**

Change:
```bash
  for tmpl in daily-retrospective weekly-report-gen weekly-finalize; do
```

To:
```bash
  for tmpl in daily-retrospective daily-retro-evening weekly-report-gen weekly-finalize; do
```

- [ ] **Step 3: Test preflight locally**

Run: `bash ~/.dotfiles/claude/crons/healthcheck.sh preflight`

Expected: Either "HEALTHCHECK OK" or specific errors about Claude Desktop not running

---

## Task 3: Update Healthcheck Postrun

**Files:**
- Modify: `~/.dotfiles/claude/crons/healthcheck.sh:94-148` (run_postrun function)

- [ ] **Step 1: Replace the entire run_postrun function**

Replace lines 94-148 with:

```bash
run_postrun() {
  local errors=()
  local dow
  dow=$(date +%u)  # 1=Mon … 7=Sun

  # Daily note check: morning task (09:00) creates YESTERDAY's note
  # By 11:00, yesterday's note should exist in the vault
  local YESTERDAY
  YESTERDAY=$(date -v-1d +%Y-%m-%d)
  if ! ls "$OBSIDIAN_VAULT/07-Daily/$YESTERDAY"*.md &>/dev/null; then
    errors+=("Daily note for $YESTERDAY not found in vault")
  fi

  # Weekly note check: on Sat/Sun/Mon, last week's summary should exist
  if [[ "$dow" =~ ^(6|7|1)$ ]]; then
    # Get last week's number
    local LAST_WEEK
    LAST_WEEK=$(date -v-7d +%Y-W%V)
    if ! ls "$OBSIDIAN_VAULT/07-Daily/$LAST_WEEK"*.md &>/dev/null; then
      errors+=("Weekly summary for $LAST_WEEK not found in vault")
    fi
  fi

  FAILURES+=("${errors[@]}")
}
```

- [ ] **Step 2: Test postrun locally**

Run: `bash ~/.dotfiles/claude/crons/healthcheck.sh postrun`

Expected: May show errors about missing notes (expected if notes don't exist yet)

- [ ] **Step 3: Commit healthcheck changes**

```bash
cd ~/.dotfiles
git add claude/crons/healthcheck.sh
git commit -m "refactor: healthcheck uses note presence instead of markers

- Preflight: Check Claude Desktop is running
- Preflight: Verify evening prompt template exists
- Postrun: Check vault for daily/weekly notes instead of marker files
- Removes dependency on launchd marker files"
```

---

## Task 4: Archive LaunchAgents

**Files:**
- Archive: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.daily-retrospective.plist`
- Archive: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.daily-retro-evening.plist`
- Archive: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.weekly-report-gen.plist`
- Archive: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.weekly-finalize.plist`

- [ ] **Step 1: Unload agents from launchd**

```bash
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.daily-retrospective.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.daily-retro-evening.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.weekly-report-gen.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.godl1ke.claude.weekly-finalize.plist 2>/dev/null || true
```

- [ ] **Step 2: Verify agents are unloaded**

Run: `launchctl list | grep -c "claude.daily\|claude.weekly"`

Expected: `0` (no matches)

- [ ] **Step 3: Create archive directory and move files**

```bash
mkdir -p ~/.dotfiles/claude/launchagents/archived/
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.daily-retrospective.plist ~/.dotfiles/claude/launchagents/archived/ 2>/dev/null || true
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.daily-retro-evening.plist ~/.dotfiles/claude/launchagents/archived/ 2>/dev/null || true
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.weekly-report-gen.plist ~/.dotfiles/claude/launchagents/archived/ 2>/dev/null || true
mv ~/.dotfiles/claude/launchagents/com.godl1ke.claude.weekly-finalize.plist ~/.dotfiles/claude/launchagents/archived/ 2>/dev/null || true
```

- [ ] **Step 4: Remove symlinks from LaunchAgents**

```bash
rm -f ~/Library/LaunchAgents/com.godl1ke.claude.daily-retrospective.plist
rm -f ~/Library/LaunchAgents/com.godl1ke.claude.daily-retro-evening.plist
rm -f ~/Library/LaunchAgents/com.godl1ke.claude.weekly-report-gen.plist
rm -f ~/Library/LaunchAgents/com.godl1ke.claude.weekly-finalize.plist
```

- [ ] **Step 5: Verify symlinks removed**

Run: `ls ~/Library/LaunchAgents/ | grep -c "claude.daily\|claude.weekly"`

Expected: `0`

- [ ] **Step 6: Commit archive changes**

```bash
cd ~/.dotfiles
git add claude/launchagents/
git commit -m "chore: archive retired launchd agents

Retired agents (replaced by Desktop Scheduled Tasks):
- daily-retrospective
- daily-retro-evening  
- weekly-report-gen
- weekly-finalize

Moved to launchagents/archived/ for rollback if needed."
```

---

## Task 5: Add Claude Desktop Login Item

- [ ] **Step 1: Check if already a login item**

Run: `osascript -e 'tell application "System Events" to get the name of every login item'`

Expected: List of login items (check if "Claude" is present)

- [ ] **Step 2: Add as login item (if not present)**

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Claude.app", hidden:false}'
```

- [ ] **Step 3: Verify login item was added**

Run: `osascript -e 'tell application "System Events" to get the name of every login item' | grep -i claude`

Expected: Shows "Claude" in output

---

## Task 6: Create Desktop Scheduled Tasks (Manual)

> **Note:** Desktop Scheduled Tasks are created via the Claude Desktop UI. This task documents the manual steps.

- [ ] **Step 1: Open Claude Desktop Settings**

1. Open Claude Desktop app
2. Press `Cmd+,` to open Settings
3. Navigate to "Scheduled Tasks" section

- [ ] **Step 2: Create daily-retrospective task**

| Field | Value |
|-------|-------|
| Name | `daily-retrospective` |
| Schedule | `0 9 * * *` or "Every day at 9:00 AM" |
| Prompt | Copy contents of `~/.dotfiles/claude/prompts/daily-retrospective.md` |
| Working Directory | `~` (home) |
| Enabled | Yes |

Click "Run Now" once to pre-approve tool permissions.

- [ ] **Step 3: Create daily-retro-evening task**

| Field | Value |
|-------|-------|
| Name | `daily-retro-evening` |
| Schedule | `30 22 * * *` or "Every day at 10:30 PM" |
| Prompt | Copy contents of `~/.dotfiles/claude/prompts/daily-retro-evening.md` |
| Working Directory | `~` (home) |
| Enabled | Yes |

Click "Run Now" once to pre-approve tool permissions.

- [ ] **Step 4: Create weekly-report task**

| Field | Value |
|-------|-------|
| Name | `weekly-report` |
| Schedule | `0 17 * * 5` or "Every Friday at 5:00 PM" |
| Prompt | Copy contents of `~/.dotfiles/claude/prompts/weekly-report-gen.md` |
| Working Directory | `~` (home) |
| Enabled | Yes |

Click "Run Now" once to pre-approve tool permissions.

- [ ] **Step 5: Create weekly-finalize task**

| Field | Value |
|-------|-------|
| Name | `weekly-finalize` |
| Schedule | `0 9 * * 1` or "Every Monday at 9:00 AM" |
| Prompt | Copy contents of `~/.dotfiles/claude/prompts/weekly-finalize.md` |
| Working Directory | `~` (home) |
| Enabled | Yes |

Click "Run Now" once to pre-approve tool permissions.

- [ ] **Step 6: Verify tasks are listed**

Run: `ls ~/.claude/scheduled-tasks/`

Expected: Shows 4 task directories

---

## Task 7: Verification

- [ ] **Step 1: Run healthcheck preflight**

Run: `bash ~/.dotfiles/claude/crons/healthcheck.sh preflight`

Expected: "HEALTHCHECK OK (preflight)" — Claude Desktop running, all prompts exist

- [ ] **Step 2: Run one scheduled task manually**

In Claude Desktop, find `daily-retro-evening` in Scheduled Tasks and click "Run Now".

Expected: Task executes, either creates or patches today's daily note

- [ ] **Step 3: Verify note in Obsidian**

Run: `ls ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/GODL1KE/07-Daily/ | grep $(date +%Y-%m-%d)`

Expected: Today's daily note file exists

- [ ] **Step 4: Run healthcheck postrun**

Run: `bash ~/.dotfiles/claude/crons/healthcheck.sh postrun`

Expected: "HEALTHCHECK OK (postrun)" — notes detected in vault

- [ ] **Step 5: Final commit**

```bash
cd ~/.dotfiles
git add -A
git status
# If any uncommitted changes, commit them
git commit -m "chore: complete pipeline hardening migration" --allow-empty
```

---

## Rollback Procedure

If issues arise, restore the launchd agents:

```bash
# Restore plist files
mv ~/.dotfiles/claude/launchagents/archived/*.plist ~/.dotfiles/claude/launchagents/

# Recreate symlinks
for plist in ~/.dotfiles/claude/launchagents/com.godl1ke.claude.{daily-retrospective,daily-retro-evening,weekly-report-gen,weekly-finalize}.plist; do
  ln -sf "$plist" ~/Library/LaunchAgents/
done

# Reload agents
launchctl load ~/Library/LaunchAgents/com.godl1ke.claude.daily-retrospective.plist
launchctl load ~/Library/LaunchAgents/com.godl1ke.claude.daily-retro-evening.plist
launchctl load ~/Library/LaunchAgents/com.godl1ke.claude.weekly-report-gen.plist
launchctl load ~/Library/LaunchAgents/com.godl1ke.claude.weekly-finalize.plist

# Disable Desktop Scheduled Tasks via UI
```

Note: Rollback restores the old system but it will continue to fail with OAuth. Only use if Desktop Scheduled Tasks have critical bugs.
