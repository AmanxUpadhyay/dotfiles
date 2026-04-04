#!/bin/bash
# PermissionRequest hook — auto-approve safe read-only operations.
# IMPORTANT: PermissionRequest uses decision.behavior, NOT permissionDecision.
# Exit 0 + JSON = structured decision. Anything else = show normal dialog.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","message":"%s"}}}\n' "$1"
  exit 0
}

# Auto-approve safe read-only tools
case "$TOOL_NAME" in
  Read|Glob|Grep|LS) allow "Safe read-only operation" ;;
esac

# Auto-approve safe bash commands
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
  if echo "$COMMAND" | grep -qE '^(git (status|log|diff|branch|show|stash list)|ls |ls$|pwd|echo |cat |head |tail |wc |grep |find |which |node --version|npm --version|npx tsc --noEmit|npm (test|run (test|lint|typecheck|build))|uv run (pytest|ruff))'; then
    allow "Safe read/build command auto-approved"
  fi
fi

exit 0
