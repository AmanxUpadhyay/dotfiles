#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PostToolUse"
fi
# =============================================================================
# auto-format.sh — Auto-Format Python Files After Edit
# =============================================================================
# purpose: deterministically formats every Python file Claude edits via ruff, guaranteeing formatting even if CLAUDE.md instructions are ignored; surfaces F401 (unused import) removals as actionable warnings so silent code mutation is visible
# inputs: stdin JSON with tool_name and tool_input.file_path (or edits[].file_path for MultiEdit); requires ruff on PATH; env AUTO_FORMAT_DRIFT_LOG optional override for drift log path
# outputs: ruff format and ruff check --fix applied in-place to edited .py files; stderr warning per removed import; appends to drift log
# side-effects: modifies .py files on disk; appends to $AUTO_FORMAT_DRIFT_LOG (default ~/.claude/logs/auto-format-drift.log); suppresses ruff crashes to avoid blocking Claude
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

DRIFT_LOG="${AUTO_FORMAT_DRIFT_LOG:-$HOME/.claude/logs/auto-format-drift.log}"

# Emit an actionable warning + drift-log entry for every F401 the peek caught.
# Silent code mutation (PR #108 incident: Path import disappeared, F821 slipped
# past the gate) is a bug class; this function makes every removal visible.
_surface_import_removals() {
  local file_path="$1"
  local diagnostics="$2"
  [ -z "$diagnostics" ] && return 0

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "auto-format: removed unused import — ${line} — verify before committing" >&2
  done <<< "$diagnostics"

  mkdir -p "$(dirname "$DRIFT_LOG")" 2>/dev/null || true
  {
    echo "[$(date -u +%FT%TZ)] tool=${TOOL_NAME} file=${file_path}"
    echo "$diagnostics"
  } >> "$DRIFT_LOG" 2>/dev/null || true
}

# Format + fix each Python file with ruff. Peek for F401 before --fix so the
# removed-import diagnostics are recoverable (ruff --fix itself only prints a
# summary). All ruff failures are swallowed — the hook must never block Claude.
while IFS= read -r FILE_PATH; do
  [ -z "$FILE_PATH" ] && continue
  [[ "$FILE_PATH" != *.py ]] && continue
  [ ! -f "$FILE_PATH" ] && continue
  command -v ruff &>/dev/null || continue

  ruff format "$FILE_PATH" >/dev/null 2>&1 || true

  F401_DIAGNOSTICS=$(ruff check --select=F401 --output-format=concise "$FILE_PATH" 2>/dev/null | grep " F401 " || true)

  ruff check --fix "$FILE_PATH" >/dev/null 2>&1 || true

  _surface_import_removals "$FILE_PATH" "$F401_DIAGNOSTICS"
done <<< "$FILE_PATHS"

exit 0
