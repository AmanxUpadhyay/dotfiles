#!/bin/bash
# =============================================================================
# GODL1KE auto-test.sh — Auto-Run Related Tests After Python Edits
# =============================================================================
# WHY: Immediate feedback loop. When Claude edits a Python file, this hook
# looks for a corresponding test file and runs it. If tests fail, Claude
# gets the error output as context (via stdout) and can fix it immediately.
# This is Boris Cherny's #1 tip: "Give Claude a way to verify its work."
#
# Runs ASYNC to avoid blocking Claude while tests execute.
#
# Location: ~/.claude/hooks/auto-test.sh
# Triggered by: PostToolUse → Write|Edit|MultiEdit (async)
# =============================================================================

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# MultiEdit carries edits[].file_path; Write/Edit carry a single file_path
if [ "$TOOL_NAME" = "MultiEdit" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.edits[].file_path // empty' 2>/dev/null | grep '\.py$' | head -1)
else
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

# Guard: not a Python file
if [[ "$FILE_PATH" != *.py ]]; then
  exit 0
fi

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
