#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostToolUse"
fi
# =============================================================================
# auto-test.sh — Auto-Run Related Tests After Python Edits
# =============================================================================
# purpose: provides immediate test feedback when Claude edits a Python file by finding and running the corresponding test file
# inputs: stdin JSON with tool_name, cwd, and file path(s); requires pytest or uv on PATH
# outputs: JSON hookSpecificOutput with additionalContext containing test failures (stdout); silent on pass
# side-effects: runs pytest subprocess; does not modify any files
# =============================================================================

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# MultiEdit carries edits[].file_path; Write/Edit carry a single file_path
if [ "$TOOL_NAME" = "MultiEdit" ]; then
  # Collect ALL Python files from MultiEdit, not just the first one
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.edits[].file_path // empty' 2>/dev/null | grep '\.py$')
else
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

# Guard: no Python files
if [[ -z "$FILE_PATHS" ]]; then
  exit 0
fi

# Use first Python file for test lookup (representative path)
FILE_PATH=$(echo "$FILE_PATHS" | head -1)

cd "$CWD" 2>/dev/null || exit 0

# Guard: no test infrastructure
if [ ! -f "pyproject.toml" ] && [ ! -f "pytest.ini" ] && [ ! -d "tests" ]; then
  exit 0
fi

# Determine test file path
BASENAME=$(basename "$FILE_PATH" .py)
DIRNAME=$(dirname "$FILE_PATH")

# Strategy 1: tests/ mirror — strip common source roots (app/, src/, lib/)
RELATIVE_PATH=${FILE_PATH#./}
STRIPPED_PATH="$RELATIVE_PATH"
for PREFIX in app/ src/ lib/; do
  STRIPPED_PATH="${STRIPPED_PATH#$PREFIX}"
done
TEST_MIRROR="tests/${STRIPPED_PATH%/*}/test_${BASENAME}.py"

# Strategy 2: test file in same directory (auth.py → test_auth.py)
TEST_SAME_DIR="${DIRNAME}/test_${BASENAME}.py"

# Strategy 3: the file IS a test file
TEST_SELF=""
if [[ "$BASENAME" == test_* ]]; then
  TEST_SELF="$FILE_PATH"
fi

# Find which test file exists
TEST_FILE=""
if [ -n "$TEST_SELF" ] && [ -f "$TEST_SELF" ]; then
  TEST_FILE="$TEST_SELF"
elif [ -f "$TEST_MIRROR" ]; then
  TEST_FILE="$TEST_MIRROR"
elif [ -f "$TEST_SAME_DIR" ]; then
  TEST_FILE="$TEST_SAME_DIR"
fi

# No related test file found — skip silently
if [ -z "$TEST_FILE" ]; then
  exit 0
fi

# Run the specific test file
if command -v uv &>/dev/null; then
  RESULT=$(uv run pytest "$TEST_FILE" --tb=short -q 2>&1)
else
  RESULT=$(pytest "$TEST_FILE" --tb=short -q 2>&1)
fi

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  # Output test failures as additional context for Claude (jq ensures safe JSON escaping)
  # PostToolUse hooks must wrap additionalContext inside hookSpecificOutput per official docs
  jq -n --arg file "$TEST_FILE" --arg result "$RESULT" \
    '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ("Test failures in " + $file + ":\n" + $result)}}'
fi

exit 0
