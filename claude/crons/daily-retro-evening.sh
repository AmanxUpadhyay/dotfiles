#!/bin/bash
set -euo pipefail
# =============================================================================
# daily-retro-evening.sh — Generate/patch today's daily note in Obsidian
# =============================================================================
# purpose: runs at 10:30pm to catch sessions created after the morning run; patches or creates today's daily note
# inputs: CLAUDE_BIN, CLAUDE_LOG_DIR, OBSIDIAN_VAULT from env.sh; prompt from daily-retrospective.md
# outputs: 07-Daily/YYYY-MM-DD-dayname.md created or patched in Obsidian vault
# side-effects: invokes claude CLI with dangerously-skip-permissions; sends macOS notification on failure
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure daily-retro-evening "$LOGFILE"' ERR

LOGFILE="$CLAUDE_LOG_DIR/daily-retro-evening-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/daily-retrospective.md"

mkdir -p "$CLAUDE_LOG_DIR"

if ! preflight_check "daily-retro-evening"; then
  echo "[$(date)] PREFLIGHT FAILED" >> "$LOGFILE"
  notify_failure "daily-retro-evening-preflight" "$LOGFILE"
  exit 1
fi

echo "[$(date)] Evening daily retrospective starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  notify_failure "daily-retro-evening" "$LOGFILE"
  exit 1
fi

export CLAUDE_AUTOMATED=1

TODAY=$(date +%Y-%m-%d)
DAY_NAME=$(date +%A)

# DATE_HINT targets TODAY and triggers patch mode if the note already exists.
DATE_HINT="EVENING RUN — Today is $TODAY ($DAY_NAME). Generate or update the daily note for TODAY $TODAY (not yesterday). First check whether a note for today already exists: search 07-Daily/ for a file matching $TODAY using mcp__obsidian__search_notes. If a note exists, read it with mcp__obsidian__read_note, identify any sessions from today NOT yet listed in ## Sessions, then use mcp__obsidian__patch_note to append only the missing sessions and refresh ## Tomorrow's Focus with new open threads. Do not remove or duplicate any existing content. If no note exists, create it fresh following the normal format below."

PROMPT="$DATE_HINT $(cat "$PROMPT_FILE")"

"$CLAUDE_BIN" \
  --print \
  --dangerously-skip-permissions \
  "$PROMPT" \
  >> "$LOGFILE" 2>&1

STATUS=$?
if [[ $STATUS -ne 0 ]]; then
  echo "[$(date)] ERROR: Claude exited with status $STATUS" >> "$LOGFILE"
  notify_failure "daily-retro-evening" "$LOGFILE"
fi

if [[ $STATUS -eq 0 ]]; then
  touch "$CLAUDE_LOG_DIR/.last-success-daily-retro-evening"
fi

echo "[$(date)] Evening daily retrospective finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
