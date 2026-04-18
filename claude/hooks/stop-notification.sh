#!/bin/bash
set -euo pipefail
# =============================================================================
# stop-notification.sh — macOS Notification When Claude Finishes a Task
# =============================================================================
# purpose: fires a macOS notification via osascript when Claude completes a non-trivial task, providing audio and visual feedback to the user
# inputs: stdin JSON with stop_reason and cwd from Stop event; CLAUDE_AUTOMATED env var
# outputs: macOS notification with task name and Glass sound via osascript
# side-effects: invokes osascript; skips in automated sessions, non-Darwin systems, and tool_use stops
# =============================================================================

INPUT=$(cat)

# Guard: skip in automated/cron-triggered sessions
[[ "$CLAUDE_AUTOMATED" == "1" ]] && exit 0

STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "completed"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Only on macOS, only on final completions (not tool_use stops)
[[ "$(uname)" != "Darwin" ]] && exit 0
[ "$STOP_REASON" = "tool_use" ] && exit 0

PROJECT=$(basename "$CWD" 2>/dev/null || echo "Claude Code")

osascript -e "display notification \"Task complete in $PROJECT\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null || true
exit 0
