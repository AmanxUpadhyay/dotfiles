#!/bin/bash
# =============================================================================
# daily-retrospective.sh — Generate yesterday's daily note in Obsidian
# =============================================================================
# Fires at 8:57am every day. Saturday firing captures Friday's work.
# Reads sessions from Obsidian MCP + meetings from Granola MCP.
# Output: 07-Daily/YYYY-MM-DD.md
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"

LOGFILE="$CLAUDE_LOG_DIR/daily-retro-$(date +%Y-%m-%d).log"
PROMPT_FILE="$HOME/.dotfiles/claude/prompts/daily-retrospective.md"

mkdir -p "$CLAUDE_LOG_DIR"
echo "[$(date)] Daily retrospective starting" >> "$LOGFILE"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[$(date)] ERROR: Prompt file not found: $PROMPT_FILE" >> "$LOGFILE"
  notify_failure "daily-retrospective" "$LOGFILE"
  exit 1
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="$HOME"
export CLAUDE_AUTOMATED=1

DATE_HINT="Today is $(date +%Y-%m-%d) ($(date +%A))."
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

echo "[$(date)] Daily retrospective finished (exit $STATUS)" >> "$LOGFILE"
exit $STATUS
