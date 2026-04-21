#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PermissionDenied"
fi
# =============================================================================
# permission-denied.sh — Log and Optionally Retry Denied Permissions
# =============================================================================
# purpose: fires after auto mode classifier denials; logs all denials to a rotating file and returns retry=true for safe read-only operations that were over-denied
# inputs: stdin JSON with tool_name, tool_input.command, session_id from PermissionDenied event
# outputs: JSON with retry=true for approved retries; appends to ~/.claude/logs/permission-denied.log
# side-effects: writes to permission-denied.log with rotation at 2000 lines (keeps last 1000); does not support exit 2
# =============================================================================

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Log all denials for visibility (with rotation at 2000 lines → keep last 1000)
LOG_FILE="$HOME/.claude/logs/permission-denied.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
echo "[$(date '+%Y-%m-%d %H:%M:%S')] session=$SESSION_ID tool=$TOOL_NAME cmd='$COMMAND'" >> "$LOG_FILE" 2>/dev/null
LINE_COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
if [[ "$LINE_COUNT" -gt 2000 ]]; then
  tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# Allow retry for safe read-only operations auto mode over-denies
# Output format: hookSpecificOutput wrapper per docs.anthropic.com/en/docs/claude-code/hooks
case "$TOOL_NAME" in
  Read|Grep|Glob)
    printf '{"hookSpecificOutput":{"hookEventName":"PermissionDenied","retry":true}}\n'
    exit 0
    ;;
esac

if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
  # Guard: don't retry chained commands — same injection risk as auto-approve
  if echo "$COMMAND" | grep -qE '(;|&&|\||`|\$\()'; then
    exit 0
  fi
  if echo "$COMMAND" | grep -qE '^(git (status|log|diff|branch|show)|ls |pwd|cat |grep |find |head |tail |wc )'; then
    printf '{"hookSpecificOutput":{"hookEventName":"PermissionDenied","retry":true}}\n'
    exit 0
  fi
fi

exit 0
