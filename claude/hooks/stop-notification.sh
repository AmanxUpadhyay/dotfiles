#!/bin/bash
# Stop hook — macOS notification when Claude finishes a task. Runs async.

INPUT=$(cat)
STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "completed"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only on macOS, only on final completions (not tool_use stops)
[[ "$(uname)" != "Darwin" ]] && exit 0
[ "$STOP_REASON" = "tool_use" ] && exit 0

PROJECT=$(basename "$CWD" 2>/dev/null || echo "Claude Code")

osascript -e "display notification \"Task complete in $PROJECT\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null || true
exit 0
