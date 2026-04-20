#!/bin/bash
set -euo pipefail
# =============================================================================
# weekly-finalize.sh — Finalize last week's draft reports
# =============================================================================
# purpose: fires at 9:03am every Monday to update last week's period from friday-draft to final and add a Week Start Focus section
# inputs: CLAUDE_BIN, CLAUDE_LOG_DIR, OBSIDIAN_VAULT from env.sh; prompt from weekly-finalize.md; optional DATE_HINT env override
# outputs: weekly report notes updated in Obsidian vault
# side-effects: invokes claude CLI with dangerously-skip-permissions; sends macOS notification on failure
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure weekly-finalize "$LOGFILE"' ERR

_START_EPOCH=$(date +%s)
LOGFILE="$CLAUDE_LOG_DIR/weekly-final-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/weekly-finalize.md"

mkdir -p "$CLAUDE_LOG_DIR"

if ! preflight_check "weekly-finalize"; then
  echo "[$(date)] PREFLIGHT FAILED" >> "$LOGFILE"
  notify_failure "weekly-finalize-preflight" "$LOGFILE"
  _DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
  echo "duration_ms=$_DURATION_MS status=fail" >> "$LOGFILE"
  exit 1
fi

echo "[$(date)] Weekly finalization starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  notify_failure "weekly-finalize" "$LOGFILE"
  _DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
  echo "duration_ms=$_DURATION_MS status=fail" >> "$LOGFILE"
  exit 1
fi

export CLAUDE_AUTOMATED=1

DATE_HINT="${DATE_HINT:-Today is $(date +%Y-%m-%d) ($(date +%A)).}"
PROMPT="$DATE_HINT $(cat "$PROMPT_FILE")"

timeout 600s "$CLAUDE_BIN" \
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
_DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
if [[ $STATUS -eq 0 ]]; then
  echo "duration_ms=$_DURATION_MS status=ok" >> "$LOGFILE"
else
  echo "duration_ms=$_DURATION_MS status=fail" >> "$LOGFILE"
fi
exit $STATUS
