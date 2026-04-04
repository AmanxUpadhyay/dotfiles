#!/bin/bash
# =============================================================================
# weekly-finalize.sh — Finalize last week's draft reports
# =============================================================================
# Fires at 9:03am every Monday. Updates period: friday-draft → final.
# Adds "Week Start Focus" section to combined summary.
# =============================================================================

LOGFILE="/tmp/claude-weekly-final-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/weekly-finalize.md"
CLAUDE="$HOME/.local/bin/claude"

echo "[$(date)] Weekly finalization starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  exit 1
fi

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="$HOME"

"$CLAUDE" \
  --print \
  --dangerously-skip-permissions \
  "$(cat "$PROMPT_FILE")" \
  >> "$LOGFILE" 2>&1

STATUS=$?
echo "[$(date)] Weekly finalization finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
