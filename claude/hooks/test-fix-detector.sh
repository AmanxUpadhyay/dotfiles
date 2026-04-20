#!/bin/bash
set -euo pipefail
# =============================================================================
# test-fix-detector.sh — Bug Jar: Detect Test File Modifications
# =============================================================================
# purpose: detects when Claude modifies a test or spec file and reminds it via additionalContext to document any bug fix in the Bug Jar at session end
# inputs: stdin JSON with tool_name and file path(s) from PostToolUse event; sources detect-org.sh for org name
# outputs: JSON hookSpecificOutput with additionalContext reminder if a test file is matched; silent otherwise
# side-effects: none; sources detect-org.sh to resolve org name for the reminder path
# =============================================================================

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Extract file paths — MultiEdit uses edits[].file_path; Edit/Write use file_path
if [ "$TOOL_NAME" = "MultiEdit" ]; then
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.edits[].file_path // empty' 2>/dev/null | sort -u)
else
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
fi

[ -z "$FILE_PATHS" ] && exit 0

# Detect test files — covers JS/TS convention (*.test.ts) AND Python convention (test_*.py / *_test.py)
MATCHED_FILE=""
while IFS= read -r FILE_PATH; do
  [ -z "$FILE_PATH" ] && continue
  if echo "$FILE_PATH" | grep -qE '\.(test|spec)\.(ts|tsx|js|jsx|py)$|(^|/)test_[^/]+\.py$|(^|/)[^/]+_test\.py$'; then
    MATCHED_FILE="$FILE_PATH"
    break
  fi
done <<< "$FILE_PATHS"

[ -z "$MATCHED_FILE" ] && exit 0

source "$HOME/.claude/hooks/detect-org.sh"

# Output additionalContext so Claude (not just the user) sees the reminder
jq -n --arg file "$MATCHED_FILE" --arg org "$DETECTED_ORG" \
  '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ("You just modified a test file (" + $file + "). If this was a bug fix, document it in a Bug Jar note at session end: 04-Knowledge/Bug-Jar/" + (now | strftime("%Y-%m-%d")) + "-<slug>.md. Include: symptom, root cause, fix, prevention. Tag with org: " + $org + ".")}}'

exit 0
