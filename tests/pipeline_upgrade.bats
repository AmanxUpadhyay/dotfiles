#!/usr/bin/env bats
# =============================================================================
# pipeline_upgrade.bats — Regression tests for 2026-04-22 pipeline upgrade
# =============================================================================

SESSION_START="$BATS_TEST_DIRNAME/../claude/hooks/session-start.sh"
# Read the repo-tracked settings.json (auto-synced with ~/.claude/settings.json) so
# assertions run against the committed diff — matches session_hooks.bats pattern and
# keeps the test file hermetic across clones.
SETTINGS="$BATS_TEST_DIRNAME/../claude/settings.json"

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

@test "settings.json permission mode is bypassPermissions" {
  # User preference confirmed 2026-04-22: bypassPermissions chosen over the
  # original defense-in-depth acceptEdits decision (PR #132 Phase 2.4).
  # permissions.allow list and permission-auto-approve.sh are retained as
  # dormant belt-and-braces — they don't fire under bypass, but stay in
  # place so a future revert back to acceptEdits is a one-line change.
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if d['permissions']['defaultMode']=='bypassPermissions' else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json contains skipDangerousModePermissionPrompt: true" {
  # Paired with bypassPermissions above — suppresses the bypass-mode warning
  # banner. Meaningless in acceptEdits mode.
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if d.get('skipDangerousModePermissionPrompt') is True else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json does not pin subagent model globally" {
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if 'CLAUDE_CODE_SUBAGENT_MODEL' not in d.get('env',{}) else 1)"
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

@test "settings.json registers PostToolUseFailure hook" {
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if 'PostToolUseFailure' in d.get('hooks',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json registers StopFailure hook" {
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if 'StopFailure' in d.get('hooks',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "settings.json registers PostCompact hook" {
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if 'PostCompact' in d.get('hooks',{}) else 1)"
  [ "$status" -eq 0 ]
}

@test "breadcrumb-writer is NOT registered for SessionEnd" {
  run python3 -c "import json,sys; d=json.load(open('$SETTINGS')); se=d.get('hooks',{}).get('SessionEnd',[]); sys.exit(1 if any('breadcrumb' in h.get('command','') for block in se for h in block.get('hooks',[])) else 0)"
  [ "$status" -eq 0 ]
}

@test "all three new log hook scripts exist and are executable" {
  [ -x "$BATS_TEST_DIRNAME/../claude/hooks/log-tool-failure.sh" ]
  [ -x "$BATS_TEST_DIRNAME/../claude/hooks/log-stop-failure.sh" ]
  [ -x "$BATS_TEST_DIRNAME/../claude/hooks/log-post-compact.sh" ]
}
