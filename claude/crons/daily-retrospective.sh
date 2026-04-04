#!/bin/bash
# =============================================================================
# daily-retrospective.sh — Generate yesterday's daily note in Obsidian
# =============================================================================
# Fires at 8:57am Mon-Sat. Saturday firing captures Friday's work.
# Reads sessions from Obsidian MCP + meetings from Granola MCP.
# Output: 07-Daily/YYYY-MM-DD.md
# =============================================================================

LOGFILE="/tmp/claude-daily-retro-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/daily-retrospective.md"
CLAUDE="$HOME/.local/bin/claude"

echo "[$(date)] Daily retrospective starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  exit 1
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="$HOME"
export CLAUDE_AUTOMATED=1

"$CLAUDE" \
  --print \
  --dangerously-skip-permissions \
  "$(cat "$PROMPT_FILE")" \
  >> "$LOGFILE" 2>&1

STATUS=$?
echo "[$(date)] Daily retrospective finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
