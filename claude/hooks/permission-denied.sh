#!/bin/bash
# PermissionDenied hook (v2.1.89+) — fires after auto mode classifier denials.
# Return {"retry": true} to let the model retry. Exit 0 silently accepts the denial.
# Does NOT support exit 2 — this is post-denial only.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Log all denials for visibility
LOG_FILE="$HOME/.claude/logs/permission-denied.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
echo "[$(date '+%Y-%m-%d %H:%M:%S')] session=$SESSION_ID tool=$TOOL_NAME cmd='$COMMAND'" >> "$LOG_FILE" 2>/dev/null

# Allow retry for safe read-only operations auto mode over-denies
case "$TOOL_NAME" in
  Read|Grep|Glob|LS)
    echo '{"retry": true}'
    exit 0
    ;;
esac

if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
  # Guard: don't retry chained commands — same injection risk as auto-approve
  if echo "$COMMAND" | grep -qE '(;|&&|\||`|\$\()'; then
    exit 0
  fi
  if echo "$COMMAND" | grep -qE '^(git (status|log|diff|branch|show)|ls |pwd|cat |grep |find |head |tail |wc )'; then
    echo '{"retry": true}'
    exit 0
  fi
fi

exit 0
