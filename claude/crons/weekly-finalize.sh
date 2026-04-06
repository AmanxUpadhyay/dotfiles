#!/bin/bash
# =============================================================================
# weekly-finalize.sh — Finalize last week's draft reports
# =============================================================================
# Fires at 9:03am every Monday. Updates period: friday-draft → final.
# Adds "Week Start Focus" section to combined summary.
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"

LOGFILE="$CLAUDE_LOG_DIR/weekly-final-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/weekly-finalize.md"

mkdir -p "$CLAUDE_LOG_DIR"

if ! preflight_check "weekly-finalize"; then
  echo "[$(date)] PREFLIGHT FAILED" >> "$LOGFILE"
  notify_failure "weekly-finalize-preflight" "$LOGFILE"
  exit 1
fi

echo "[$(date)] Weekly finalization starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  notify_failure "weekly-finalize" "$LOGFILE"
  exit 1
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="$HOME"
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
  notify_failure "weekly-finalize" "$LOGFILE"
fi

if [[ $STATUS -eq 0 ]]; then
  touch "$CLAUDE_LOG_DIR/.last-success-weekly-finalize"
fi

echo "[$(date)] Weekly finalization finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
