#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "StopFailure"
fi
# =============================================================================
# log-stop-failure.sh — Log Session Stop Failures
# =============================================================================
# purpose: records session-level failures (rate limit, auth, billing) that
#          currently fail silently; makes them visible in hook-health digest
# inputs: stdin JSON with failure category/reason from StopFailure event
# outputs: exit 0 (never blocks); appends structured detail to hooks log
# side-effects: single line append to $CLAUDE_LOG_DIR/hooks-fire.log
# =============================================================================

INPUT=$(cat)
CATEGORY=$(echo "$INPUT" | jq -r '.failure_category // .category // "unknown"')
REASON=$(echo "$INPUT" | jq -r '.reason // .error // empty' | head -c 200)

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]] && command -v jq &>/dev/null; then
  LOG_FILE="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "StopFailure.detail" \
        --arg category "$CATEGORY" \
        --arg reason "$REASON" \
        '{ts:$ts, event:$event, category:$category, reason:$reason}' >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
