#!/usr/bin/env bats
# =============================================================================
# pipeline_upgrade.bats — Regression tests for 2026-04-22 pipeline upgrade
# =============================================================================

SESSION_START="$BATS_TEST_DIRNAME/../claude/hooks/session-start.sh"
SETTINGS="$HOME/.claude/settings.json"

@test "session-start.sh does not contain claude-mem curl block" {
  run grep -c '/api/search?query=' "$SESSION_START"
  [ "$status" -ne 0 ] || [ "$output" -eq 0 ]
}

@test "session-start.sh does not reference CLAUDE_MEM_WORKER_PORT in a curl" {
  run grep -E 'curl.*CLAUDE_MEM_WORKER_PORT|curl.*127\.0\.0\.1:\$\{CLAUDE_MEM' "$SESSION_START"
  [ "$status" -ne 0 ]
}

@test "session-start.sh still outputs hookSpecificOutput at end" {
  run grep -F 'hookSpecificOutput' "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "session-end-note.sh has been removed" {
  [ ! -e "$HOME/.claude/hooks/session-end-note.sh" ]
}

@test "/session-note command file has been removed" {
  [ ! -e "$BATS_TEST_DIRNAME/../claude/commands/session-note.md" ]
  [ ! -e "$HOME/.claude/commands/session-note.md" ]
}
