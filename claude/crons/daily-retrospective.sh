#!/bin/bash
set -euo pipefail
# =============================================================================
# daily-retrospective.sh — Generate yesterday's daily note in Obsidian
# =============================================================================
# purpose: fires at 8:57am every day to write yesterday's daily note; Saturday captures Friday's work
# inputs: CLAUDE_BIN, CLAUDE_LOG_DIR, OBSIDIAN_VAULT from env.sh; prompt from daily-retrospective.md; optional DATE_HINT env override
# outputs: 07-Daily/YYYY-MM-DD.md created in Obsidian vault
# side-effects: invokes claude CLI with dangerously-skip-permissions; sends macOS notification on failure
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure daily-retrospective "$LOGFILE"' ERR

LOGFILE="$CLAUDE_LOG_DIR/daily-retro-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/daily-retrospective.md"

mkdir -p "$CLAUDE_LOG_DIR"

if ! preflight_check "daily-retrospective"; then
  echo "[$(date)] PREFLIGHT FAILED" >> "$LOGFILE"
  notify_failure "daily-retrospective-preflight" "$LOGFILE"
  exit 1
fi

echo "[$(date)] Daily retrospective starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  notify_failure "daily-retrospective" "$LOGFILE"
  exit 1
fi

export CLAUDE_AUTOMATED=1

DATE_HINT="${DATE_HINT:-Today is $(date +%Y-%m-%d) ($(date +%A)).}"
PROMPT="$DATE_HINT $(cat "$PROMPT_FILE")"

"$CLAUDE_BIN" \
  --print \
  --dangerously-skip-permissions \
  "$PROMPT" \
  >> "$LOGFILE" 2>&1

STATUS=$?
if [[ $STATUS -ne 0 ]]; then
  echo "[$(date)] ERROR: Claude exited with status $STATUS" >> "$LOGFILE"
  notify_failure "daily-retrospective" "$LOGFILE"
fi

if [[ $STATUS -eq 0 ]]; then
  touch "$CLAUDE_LOG_DIR/.last-success-daily-retrospective"
fi

echo "[$(date)] Daily retrospective finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
