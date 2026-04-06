#!/bin/bash
# =============================================================================
# weekly-report-gen.sh — Generate Friday weekly reports in Obsidian
# =============================================================================
# Fires at 5:02pm every Friday. Generates per-org reports + combined summary.
# Reads Mon-Fri daily notes from Obsidian MCP.
# Output: per-org reports + 07-Daily/YYYY-WNN-weekly-summary.md
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"

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
  notify_failure "weekly-report-gen" "$LOGFILE"
fi

if [[ $STATUS -eq 0 ]]; then
  touch "$CLAUDE_LOG_DIR/.last-success-weekly-report-gen"
fi

echo "[$(date)] Weekly report generation finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
