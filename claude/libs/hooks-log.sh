#!/bin/bash
# =============================================================================
# hooks-log.sh — NDJSON logger shared by all Claude Code hooks
# =============================================================================
# purpose: every hook sources this and calls `log_hook_fire <event> [extra]`
#   at entry to write one NDJSON line to $CLAUDE_LOG_DIR/hooks-fire.log.
#   Hooks can optionally call `log_hook_exit <event> <code>` (typically via
#   trap) on completion. The log is append-only NDJSON so later tooling
#   (`jq`, Python) can parse it cheaply. Fails open — logging errors never
#   abort a hook.
# inputs: CLAUDE_LOG_DIR (optional; defaults to ~/Library/Logs/claude-crons)
# outputs: appends to $CLAUDE_LOG_DIR/hooks-fire.log
# side-effects: creates the log directory if missing; no stdout/stderr noise
# =============================================================================

# Guard against double-sourcing (env.sh follows the same pattern).
[[ -n "${_HOOKS_LOG_SOURCED:-}" ]] && return 0
_HOOKS_LOG_SOURCED=1

# Resolve the log file path. Falls back to the canonical location if env.sh
# hasn't been sourced yet — keeps the library standalone-usable (e.g. in tests).
HOOKS_FIRE_LOG="${CLAUDE_LOG_DIR:-$HOME/Library/Logs/claude-crons}/hooks-fire.log"

# Create the parent directory silently; never crash a hook over a missing dir.
mkdir -p "$(dirname "$HOOKS_FIRE_LOG")" 2>/dev/null || true

# Emit one NDJSON line recording that a hook fired.
# Usage: log_hook_fire <event> [extra_json_object]
#   event: Stop, SessionStart, PostToolUse, etc.
#   extra_json_object: a valid JSON object literal; defaults to {}
log_hook_fire() {
  local event="${1:-unknown}"
  local extra='{}'
  [[ -n "${2:-}" ]] && extra="$2"
  local hook
  hook=$(basename "${BASH_SOURCE[1]:-$0}")
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq -cn \
    --arg ts "$ts" \
    --arg event "$event" \
    --arg hook "$hook" \
    --argjson pid "$$" \
    --argjson extra "$extra" \
    '{ts:$ts, event:$event, hook:$hook, pid:$pid, extra:$extra}' \
    >> "$HOOKS_FIRE_LOG" 2>/dev/null || true
}

# Emit an exit-line NDJSON entry. Typically set up via:
#   trap 'log_hook_exit "Stop" "$?"' EXIT
# Usage: log_hook_exit <event> <exit_code> [extra_json_object]
log_hook_exit() {
  local event="${1:-unknown}"
  local exit_code="${2:-0}"
  local extra='{}'
  [[ -n "${3:-}" ]] && extra="$3"
  local hook
  hook=$(basename "${BASH_SOURCE[1]:-$0}")
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq -cn \
    --arg ts "$ts" \
    --arg event "${event}.exit" \
    --arg hook "$hook" \
    --argjson pid "$$" \
    --argjson exit_code "$exit_code" \
    --argjson extra "$extra" \
    '{ts:$ts, event:$event, hook:$hook, pid:$pid, exit_code:$exit_code, extra:$extra}' \
    >> "$HOOKS_FIRE_LOG" 2>/dev/null || true
}
