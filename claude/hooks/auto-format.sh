#!/bin/bash
# =============================================================================
# GODL1KE auto-format.sh — Auto-Format Python Files After Edit
# =============================================================================
# WHY: Deterministic formatting via hooks, not CLAUDE.md instructions.
# Claude might ignore a "use ruff" instruction in CLAUDE.md. This hook
# GUARANTEES every edited Python file gets formatted. Runs ruff format
# on the specific file that was just edited — fast and non-blocking.
#
# Location: ~/.claude/hooks/auto-format.sh
# Triggered by: PostToolUse → Write|Edit|MultiEdit
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
