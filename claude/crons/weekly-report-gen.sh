#!/bin/bash
# =============================================================================
# weekly-report-gen.sh — Generate Friday weekly reports in Obsidian
# =============================================================================
# Fires at 5:02pm every Friday. Generates per-org reports + combined summary.
# Reads Mon-Fri daily notes from Obsidian MCP.
# Output: per-org reports + 07-Daily/YYYY-WNN-weekly-summary.md
# =============================================================================

LOGFILE="/tmp/claude-weekly-gen-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/weekly-report-gen.md"
CLAUDE="$HOME/.local/bin/claude"

echo "[$(date)] Weekly report generation starting" >> "$LOGFILE"

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
echo "[$(date)] Weekly report generation finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
