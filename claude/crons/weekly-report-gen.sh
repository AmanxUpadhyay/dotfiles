#!/bin/bash
set -euo pipefail
# =============================================================================
# weekly-report-gen.sh — Generate Friday weekly reports in Obsidian
# =============================================================================
# purpose: fires at 5:02pm every Friday to generate per-org weekly reports and a combined summary from Mon-Fri daily notes
# inputs: CLAUDE_BIN, CLAUDE_LOG_DIR, OBSIDIAN_VAULT from env.sh; prompt from weekly-report-gen.md; optional DATE_HINT env override
# outputs: per-org report notes + 07-Daily/YYYY-WNN-weekly-summary.md written to Obsidian vault
# side-effects: invokes claude CLI with dangerously-skip-permissions; sends macOS notification on failure
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure weekly-report-gen "$LOGFILE"' ERR

LOGFILE="$CLAUDE_LOG_DIR/weekly-gen-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/weekly-report-gen.md"

mkdir -p "$CLAUDE_LOG_DIR"

if ! preflight_check "weekly-report-gen"; then
  echo "[$(date)] PREFLIGHT FAILED" >> "$LOGFILE"
  notify_failure "weekly-report-gen-preflight" "$LOGFILE"
  exit 1
fi

echo "[$(date)] Weekly report generation starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  notify_failure "weekly-report-gen" "$LOGFILE"
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
  notify_failure "weekly-report-gen" "$LOGFILE"
fi

if [[ $STATUS -eq 0 ]]; then
  touch "$CLAUDE_LOG_DIR/.last-success-weekly-report-gen"
fi

echo "[$(date)] Weekly report generation finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
