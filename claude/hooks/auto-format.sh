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
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Guard: no file path or not a Python file
if [ -z "$FILE_PATH" ] || [[ "$FILE_PATH" != *.py ]]; then
  exit 0
fi

# Guard: file doesn't exist (might have been deleted)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Format with ruff (suppress errors — don't block Claude if ruff fails)
if command -v ruff &>/dev/null; then
  ruff format "$FILE_PATH" 2>/dev/null
  ruff check --fix "$FILE_PATH" 2>/dev/null
fi

exit 0
