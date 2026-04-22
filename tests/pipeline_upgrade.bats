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

@test "settings.json permission mode is acceptEdits" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if d['permissions']['defaultMode']=='acceptEdits' else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json does not contain skipDangerousModePermissionPrompt" {
  run grep -c skipDangerousModePermissionPrompt "$HOME/.claude/settings.json"
  [ "$status" -ne 0 ] || [ "$output" -eq 0 ]
}

@test "settings.json does not pin subagent model globally" {
  run python3 -c "import json,sys; d=json.load(open('$HOME/.claude/settings.json')); sys.exit(0 if 'CLAUDE_CODE_SUBAGENT_MODEL' not in d.get('env',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "code-reviewer agent pinned to Opus 4.7" {
  run grep -E '^model: claude-opus-4-7' "$BATS_TEST_DIRNAME/../claude/agents/code-reviewer.md"
  [ "$status" -eq 0 ]
}

@test "researcher agent pinned to Opus 4.7" {
  run grep -E '^model: claude-opus-4-7' "$BATS_TEST_DIRNAME/../claude/agents/researcher.md"
  [ "$status" -eq 0 ]
}
