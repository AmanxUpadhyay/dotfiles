#!/bin/bash
set -euo pipefail
# =============================================================================
# smart-checkpoint.sh — Detect milestone moments in Bash/Task PostToolUse
# =============================================================================
# purpose: fires on PostToolUse for Bash|Task tools; detects milestone-class
#   events (git push, test run, PR create, Task completion) and emits an
#   additionalContext reminder for Claude to append a brief checkpoint bullet
#   to today's session note under ## Checkpoints. Passive — does not force the
#   write. Complements session-stop.sh (which fires at turn-end) by surfacing
#   the moment mid-turn so Claude can capture the semantic beat.
# inputs: stdin JSON with tool_name, tool_input.command; CLAUDE_AUTOMATED env
# outputs: JSON hookSpecificOutput with additionalContext when a milestone
#   is detected; silent (exit 0 no output) otherwise
# side-effects: none — emits context only, no filesystem writes
# =============================================================================

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostToolUse"
fi

INPUT=$(cat 2>/dev/null || echo "{}")

# Guard: skip in automated/cron-triggered sessions.
[[ "${CLAUDE_AUTOMATED:-}" == "1" ]] && exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

DETECTED=""

case "$TOOL_NAME" in
  Task)
    DETECTED="Task (subagent) completion"
    ;;
  Bash)
    if [[ -n "$COMMAND" ]]; then
      CMD_TRIMMED="${COMMAND#"${COMMAND%%[![:space:]]*}"}"  # ltrim
      case "$CMD_TRIMMED" in
        *"git push"*)                       DETECTED="git push" ;;
        *"gh pr create"*|*"gh pr merge"*)   DETECTED="PR creation/merge" ;;
        *"pytest"*)                         DETECTED="pytest run" ;;
        *"npm test"*|*"npm run test"*)      DETECTED="npm test run" ;;
        *"ruff check"*)                     DETECTED="ruff check" ;;
        *"bats tests"*|*"bats test"*)       DETECTED="bats test run" ;;
        *"uv run pytest"*)                  DETECTED="uv pytest run" ;;
      esac
    fi
    ;;
esac

[[ -z "$DETECTED" ]] && exit 0

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

# Emit additionalContext. Passive reminder — Claude decides whether to record
# this as a milestone bullet. Avoids spamming the session note on every Bash
# call; lets Claude's own judgment filter real milestones from noise.
jq -cn \
  --arg date "$DATE" \
  --arg time "$TIME" \
  --arg detected "$DETECTED" \
  '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("📌 Checkpoint moment: \($detected) at \($time). If this represents a milestone worth preserving, append a one-line bullet to today'\''s session note at 06-Sessions/<org>/\($date)-<slug>.md under a `## Checkpoints` section (create the section if it doesn'\''t exist). Format: `- **\($time)** — <what just happened>`.")
    }
  }'
