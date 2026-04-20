#!/bin/bash
set -euo pipefail
# =============================================================================
# auto-format.sh — Auto-Format Python Files After Edit
# =============================================================================
# purpose: deterministically formats every Python file Claude edits via ruff, guaranteeing formatting even if CLAUDE.md instructions are ignored
# inputs: stdin JSON with tool_name and tool_input.file_path (or edits[].file_path for MultiEdit); requires ruff on PATH
# outputs: ruff format and ruff check --fix applied in-place to edited .py files
# side-effects: modifies .py files on disk; suppresses ruff errors to avoid blocking Claude
# =============================================================================

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# MultiEdit carries an edits[] array; Write/Edit carry a single file_path
if [ "$TOOL_NAME" = "MultiEdit" ]; then
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.edits[].file_path // empty' 2>/dev/null | sort -u)
else
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

# Guard: nothing to format
if [ -z "$FILE_PATHS" ]; then
  exit 0
fi

# Format each Python file with ruff (suppress errors — don't block Claude if ruff fails)
while IFS= read -r FILE_PATH; do
  [ -z "$FILE_PATH" ] && continue
  [[ "$FILE_PATH" != *.py ]] && continue
  [ ! -f "$FILE_PATH" ] && continue
  if command -v ruff &>/dev/null; then
    ruff format "$FILE_PATH" 2>/dev/null
    ruff check --fix "$FILE_PATH" 2>/dev/null
  fi
done <<< "$FILE_PATHS"

exit 0
