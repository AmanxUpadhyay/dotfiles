#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostCompact"
fi
# =============================================================================
# log-post-compact.sh — Log Context Compaction Events
# =============================================================================
# purpose: records when context compaction completes, pairing with precompact.sh
#          for before/after visibility in the daily hook-health digest
# inputs: stdin JSON with source (auto/manual), trigger, token_count from PostCompact
# outputs: exit 0 (never blocks); appends structured detail to hooks log
# side-effects: single line append to $CLAUDE_LOG_DIR/hooks-fire.log
# =============================================================================

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // .trigger // "unknown"')
TOKENS=$(echo "$INPUT" | jq -r '.token_count // empty')

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]] && command -v jq &>/dev/null; then
  LOG_FILE="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}/hooks-fire.log"
  mkdir -p "$(dirname "$LOG_FILE")"
  jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "PostCompact.detail" \
        --arg source "$SOURCE" \
        --arg tokens "$TOKENS" \
        '{ts:$ts, event:$event, source:$source, tokens:$tokens}' >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
