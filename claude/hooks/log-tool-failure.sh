#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostToolUseFailure"
fi
# =============================================================================
# log-tool-failure.sh — Log Silent Tool Failures
# =============================================================================
# purpose: records failed tool invocations so silent Write/Edit/Bash failures
#          surface in the daily hook-health digest instead of vanishing
# inputs: stdin JSON with tool_name and error/error_message from PostToolUseFailure
# outputs: exit 0 (never blocks); appends a structured line to the hooks log
# side-effects: single line append to $CLAUDE_LOG_DIR/hooks-fire.log via hooks-log.sh
# =============================================================================

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
ERR=$(echo "$INPUT" | jq -r '.error // .error_message // empty' | head -c 200)

# hooks-log.sh's log_hook_fire already wrote the bare event. Append detail as
# a second structured line so the daily digest can count tool-failure events
# by tool name.
if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]] && command -v jq &>/dev/null; then
  LOG_FILE="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "PostToolUseFailure.detail" \
        --arg tool "$TOOL" \
        --arg err "$ERR" \
        '{ts:$ts, event:$event, tool:$tool, error:$err}' >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
