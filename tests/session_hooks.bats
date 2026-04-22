#!/usr/bin/env bats
# =============================================================================
# session_hooks.bats — Regression tests for session-lifecycle hooks
# =============================================================================
# Covers:
#   1. Static: every script path referenced in settings.json SessionEnd/Stop
#      hook commands resolves to a file in claude/hooks/ (repo-tracked).
#      Regression: dangling session-end-note.sh reference.
#   2. session-stop.sh — happy path: emits `decision:block` JSON for today.
#   3. session-stop.sh — stop_hook_active=true short-circuits silently.
#   4. session-stop.sh — CLAUDE_AUTOMATED=1 short-circuits silently.
#   5. session-stop.sh — survives unset CLAUDE_AUTOMATED under `set -u`
#      (regression: bare `$CLAUDE_AUTOMATED` used to abort the script).
#   6. breadcrumb-writer.sh — writes .claude/breadcrumbs.md with expected fields.
#   7. breadcrumb-writer.sh — CLAUDE_AUTOMATED=1 short-circuits silently.
#   8. breadcrumb-writer.sh — outside a git repo short-circuits silently.
#   9. breadcrumb-writer.sh — survives unset CLAUDE_AUTOMATED under `set -u`.
#
# Run with: bats tests/session_hooks.bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."
SETTINGS="$REPO_ROOT/claude/settings.json"
SESSION_STOP="$REPO_ROOT/claude/hooks/session-stop.sh"
BREADCRUMB="$REPO_ROOT/claude/hooks/breadcrumb-writer.sh"

fail() {
  echo "$@" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Shared setup: HOME points at a temp dir with symlinks to the in-repo env.sh
# and detect-org.sh so the hooks source the code-under-test. An ORG_MAP is
# written to the path env.sh will resolve to.
# ---------------------------------------------------------------------------
setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude/hooks"
  ln -sf "$REPO_ROOT/claude/env.sh"              "$HOME/.claude/env.sh"
  ln -sf "$REPO_ROOT/claude/hooks/detect-org.sh" "$HOME/.claude/hooks/detect-org.sh"

  # env.sh resolves ORG_MAP to $HOME/.claude/org-map.json — populate it.
  cat > "$HOME/.claude/org-map.json" <<'EOF'
{
  "mappings": [],
  "default_org": "Personal",
  "orgs": {
    "Personal": {
      "wikilink": "[[Personal]]",
      "vault_folder": "Personal",
      "session_folder": "Personal"
    }
  }
}
EOF

  export OBSIDIAN_VAULT="$BATS_TEST_TMPDIR/vault"
  mkdir -p "$OBSIDIAN_VAULT/06-Sessions/Personal"

  export CLAUDE_LOG_DIR="$BATS_TEST_TMPDIR/logs"
  mkdir -p "$CLAUDE_LOG_DIR"

  unset CLAUDE_AUTOMATED
  unset CLAUDE_PROJECT_DIR
}

# Helper: feed JSON to a hook via a pipe, without nested bash -c quoting.
_run_hook() {
  local hook="$1"; shift
  local json="$1"; shift
  local stdin_file="$BATS_TEST_TMPDIR/stdin-$$"
  printf '%s' "$json" > "$stdin_file"
  run bash -c "bash '$hook' < '$stdin_file'"
}

# ---------------------------------------------------------------------------
# 1. Static config: referenced scripts exist in the repo
# ---------------------------------------------------------------------------
@test "settings.json SessionEnd script refs valid when present (absence enforced by pipeline_upgrade.bats)" {
  # Absence of SessionEnd is the primary invariant — enforced by
  # pipeline_upgrade.bats test "breadcrumb-writer is NOT registered for SessionEnd".
  # THIS test is a graceful future-proofing guard: if SessionEnd is ever
  # re-introduced (e.g., for a non-breadcrumb hook), each referenced script
  # must exist in the repo. Re-introduction without that check would let a
  # dangling-script hook pass unnoticed.
  local has_session_end
  has_session_end=$(jq -r '.hooks | has("SessionEnd")' "$SETTINGS")
  if [ "$has_session_end" = "true" ]; then
    local cmds
    cmds=$(jq -r '.hooks.SessionEnd[].hooks[].command' "$SETTINGS")
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      local script
      script=$(echo "$cmd" | sed -n 's|.*\$HOME/\.claude/hooks/\([A-Za-z0-9._-]*\).*|\1|p')
      [ -n "$script" ] || fail "could not parse script name from command: $cmd"
      [ -f "$REPO_ROOT/claude/hooks/$script" ] \
        || fail "SessionEnd references claude/hooks/$script but file is missing"
    done <<< "$cmds"
  fi
}

@test "settings.json Stop hook commands all point to existing repo scripts" {
  local cmds
  cmds=$(jq -r '.hooks.Stop[].hooks[].command' "$SETTINGS")
  [ -n "$cmds" ] || fail "no Stop commands found in settings.json"

  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    local script
    script=$(echo "$cmd" | sed -n 's|.*\$HOME/\.claude/hooks/\([A-Za-z0-9._-]*\).*|\1|p')
    [ -n "$script" ] || fail "could not parse script name from command: $cmd"
    [ -f "$REPO_ROOT/claude/hooks/$script" ] \
      || fail "Stop references claude/hooks/$script but file is missing"
  done <<< "$cmds"
}

@test "settings.json: session-stop.sh registered as synchronous on Stop" {
  # Regression: async:true makes the harness ignore `decision:block`, so the
  # script's design intent (force a summary-note write) was nominal only.
  # Must be async:false. stop-notification.sh can stay async — it's cosmetic.
  local async
  async=$(jq -r '.hooks.Stop[].hooks[] | select(.command | contains("session-stop.sh")) | .async' "$SETTINGS")
  [ "$async" = "false" ] \
    || fail "session-stop.sh must be async:false (got: $async); async:true makes decision:block a no-op"
}

@test "settings.json: breadcrumb-writer wired to Stop only (SessionEnd removed 2026-04-22)" {
  # Stop fires every turn — the breadcrumb stays fresh even on Cmd+Q/SIGKILL
  # because Stop runs during normal turn-end before the force-quit can land.
  # SessionEnd wiring was removed because it double-fired the breadcrumb
  # writer without adding reliability.
  local on_stop on_session_end
  on_stop=$(jq -r '.hooks.Stop[].hooks[] | select(.command | contains("breadcrumb-writer.sh")) | .command' "$SETTINGS")
  on_session_end=$(jq -r '.hooks | (if has("SessionEnd") then .SessionEnd[].hooks[] | select(.command | contains("breadcrumb-writer.sh")) | .command else empty end)' "$SETTINGS")
  [ -n "$on_stop" ] \
    || fail "breadcrumb-writer.sh must be wired to Stop (for Cmd+Q survival)"
  [ -z "$on_session_end" ] \
    || fail "breadcrumb-writer.sh should NOT be wired to SessionEnd anymore (removed 2026-04-22 to eliminate double-fire)"
}

@test "settings.json: breadcrumb-writer on Stop is async:true" {
  # Breadcrumb write is lightweight (<10ms) and must never block Claude's
  # completion. stop-notification.sh is the precedent.
  local async
  async=$(jq -r '.hooks.Stop[].hooks[] | select(.command | contains("breadcrumb-writer.sh")) | .async' "$SETTINGS")
  [ "$async" = "true" ] \
    || fail "breadcrumb-writer.sh on Stop must be async:true (got: $async)"
}

# ---------------------------------------------------------------------------
# 2-5. session-stop.sh
# ---------------------------------------------------------------------------
@test "session-stop PATCH mode: existing today-note triggers PATCH instruction" {
  # Pre-create a today-note for Personal org so the hook sees it and switches
  # from CREATE to PATCH mode.
  local today existing
  today=$(date +%Y-%m-%d)
  existing="$OBSIDIAN_VAULT/06-Sessions/Personal/${today}-existing-slug.md"
  mkdir -p "$(dirname "$existing")"
  echo "stub note" > "$existing"

  # Fake a transcript with a tool_use so the trivial-session guard doesn't skip.
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  printf '{"message":{"content":[{"type":"tool_use","name":"Write"}]}}\n' > "$transcript"

  local json
  json=$(jq -cn --arg t "$transcript" '{session_id:"t",hook_event_name:"Stop",stop_hook_active:false,transcript_path:$t,cwd:"/tmp"}')
  _run_hook "$SESSION_STOP" "$json"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"

  local reason
  reason=$(echo "$output" | jq -r '.reason')
  [[ "$reason" == *"PATCH"* ]] \
    || fail "expected PATCH instruction in reason, got: $reason"
  [[ "$reason" == *"${today}-existing-slug.md"* ]] \
    || fail "expected existing filename in reason, got: $reason"
  [[ "$reason" != *"choose a descriptive"* ]] \
    || fail "PATCH mode must NOT include 'choose a descriptive <slug>' (that's CREATE-mode wording): $reason"
}

@test "session-stop CREATE mode: no today-note yet triggers CREATE instruction" {
  # Ensure no today-note exists (setup creates a fresh temp OBSIDIAN_VAULT).
  local today
  today=$(date +%Y-%m-%d)

  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  printf '{"message":{"content":[{"type":"tool_use","name":"Write"}]}}\n' > "$transcript"

  local json
  json=$(jq -cn --arg t "$transcript" '{session_id:"t",hook_event_name:"Stop",stop_hook_active:false,transcript_path:$t,cwd:"/tmp"}')
  _run_hook "$SESSION_STOP" "$json"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"

  local reason
  reason=$(echo "$output" | jq -r '.reason')
  [[ "$reason" == *"choose a descriptive"* ]] \
    || fail "expected CREATE-mode 'choose a descriptive <slug>' wording, got: $reason"
  [[ "$reason" != *"PATCH"* ]] \
    || fail "CREATE mode must NOT include PATCH wording: $reason"
}

@test "session-stop emits decision=block JSON for today's date on happy path" {
  local today
  today=$(date +%Y-%m-%d)
  _run_hook "$SESSION_STOP" \
    '{"session_id":"t","hook_event_name":"Stop","stop_hook_active":false,"transcript_path":"/nonexistent","cwd":"/tmp"}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  echo "$output" | grep -q '"decision": "block"' \
    || fail "expected decision=block in output. got: $output"
  echo "$output" | grep -q "$today" \
    || fail "expected today's date ($today) in output. got: $output"
  echo "$output" | grep -q "06-Sessions/Personal" \
    || fail "expected session folder path. got: $output"
}

@test "session-stop short-circuits when stop_hook_active=true" {
  _run_hook "$SESSION_STOP" \
    '{"session_id":"t","hook_event_name":"Stop","stop_hook_active":true}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  [ -z "$output" ] || fail "expected no output. got: $output"
}

@test "session-stop short-circuits when CLAUDE_AUTOMATED=1" {
  export CLAUDE_AUTOMATED=1
  _run_hook "$SESSION_STOP" \
    '{"session_id":"t","hook_event_name":"Stop","stop_hook_active":false}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  [ -z "$output" ] || fail "expected no output. got: $output"
}

@test "session-stop survives unset CLAUDE_AUTOMATED under set -u" {
  # Regression: bare `$CLAUDE_AUTOMATED` aborted the script in normal sessions
  # where the var is unset, so the block decision never reached Claude.
  unset CLAUDE_AUTOMATED
  _run_hook "$SESSION_STOP" \
    '{"session_id":"t","hook_event_name":"Stop","stop_hook_active":false}'
  [ "$status" -eq 0 ] || fail "expected exit 0 with unset CLAUDE_AUTOMATED, got $status. output: $output"
  echo "$output" | grep -q '"decision": "block"' \
    || fail "expected block decision. got: $output"
}

# ---------------------------------------------------------------------------
# 6-9. breadcrumb-writer.sh
# ---------------------------------------------------------------------------
@test "breadcrumb-writer logs the real hook_event_name (Stop vs SessionEnd)" {
  # Regression: hook is wired to both Stop and SessionEnd; the fire-log label
  # must reflect which event actually fired rather than a hardcoded string.
  local proj="$BATS_TEST_TMPDIR/proj-event-label"
  mkdir -p "$proj"
  (cd "$proj" && git init -q && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init)
  export CLAUDE_PROJECT_DIR="$proj"

  # Symlink the hooks-log lib into the fake HOME so the logging branch runs.
  mkdir -p "$HOME/.claude/libs"
  ln -sf "$REPO_ROOT/claude/libs/hooks-log.sh" "$HOME/.claude/libs/hooks-log.sh"

  _run_hook "$BREADCRUMB" '{"session_id":"abc","hook_event_name":"Stop"}'
  [ "$status" -eq 0 ]
  [ -f "$CLAUDE_LOG_DIR/hooks-fire.log" ]
  run jq -r '.event' "$CLAUDE_LOG_DIR/hooks-fire.log"
  [ "$output" = "Stop" ] \
    || fail "expected event=Stop (from hook_event_name), got: $output"

  rm -f "$CLAUDE_LOG_DIR/hooks-fire.log"

  _run_hook "$BREADCRUMB" '{"session_id":"abc","hook_event_name":"SessionEnd"}'
  [ "$status" -eq 0 ]
  run jq -r '.event' "$CLAUDE_LOG_DIR/hooks-fire.log"
  [ "$output" = "SessionEnd" ] \
    || fail "expected event=SessionEnd, got: $output"
}

@test "breadcrumb-writer writes .claude/breadcrumbs.md with expected fields" {
  local proj="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$proj"
  (cd "$proj" && git init -q && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init)
  export CLAUDE_PROJECT_DIR="$proj"

  _run_hook "$BREADCRUMB" '{"session_id":"abc-123","hook_event_name":"SessionEnd"}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"

  local crumb="$proj/.claude/breadcrumbs.md"
  [ -f "$crumb" ] || fail "breadcrumb file not written to $crumb"
  grep -q "Latest session:" "$crumb" || fail "missing 'Latest session' header"
  grep -q "Session ID: abc-123" "$crumb" || fail "session_id not propagated"
  grep -q "Organisation:" "$crumb" || fail "missing Organisation line"
}

@test "breadcrumb-writer short-circuits when CLAUDE_AUTOMATED=1" {
  local proj="$BATS_TEST_TMPDIR/proj-auto"
  mkdir -p "$proj"
  (cd "$proj" && git init -q && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init)
  export CLAUDE_PROJECT_DIR="$proj"
  export CLAUDE_AUTOMATED=1

  _run_hook "$BREADCRUMB" '{"session_id":"x","hook_event_name":"SessionEnd"}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status"
  [ ! -f "$proj/.claude/breadcrumbs.md" ] \
    || fail "should not write breadcrumb when CLAUDE_AUTOMATED=1"
}

@test "breadcrumb-writer short-circuits when CWD is not inside a git repo" {
  local non_repo="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$non_repo"
  export CLAUDE_PROJECT_DIR="$non_repo"

  _run_hook "$BREADCRUMB" '{"session_id":"y","hook_event_name":"SessionEnd"}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  [ ! -f "$non_repo/.claude/breadcrumbs.md" ] \
    || fail "should not write breadcrumb outside a git repo"
}

@test "breadcrumb-writer survives unset CLAUDE_AUTOMATED under set -u" {
  # Regression: bare `$CLAUDE_AUTOMATED` aborted the script in normal sessions
  # where the var is unset, so the breadcrumb never updated.
  local proj="$BATS_TEST_TMPDIR/proj-unset"
  mkdir -p "$proj"
  (cd "$proj" && git init -q && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init)
  export CLAUDE_PROJECT_DIR="$proj"
  unset CLAUDE_AUTOMATED

  _run_hook "$BREADCRUMB" '{"session_id":"u","hook_event_name":"SessionEnd"}'
  [ "$status" -eq 0 ] || fail "expected exit 0 with unset CLAUDE_AUTOMATED, got $status. output: $output"
  [ -f "$proj/.claude/breadcrumbs.md" ] || fail "breadcrumb should still be written"
}

# ---------------------------------------------------------------------------
# 10-13. precompact.sh — PreCompact safety net for session-note finalization
# ---------------------------------------------------------------------------
PRECOMPACT="$REPO_ROOT/claude/hooks/precompact.sh"

@test "settings.json PreCompact hook commands all point to existing repo scripts" {
  local cmds
  cmds=$(jq -r '.hooks.PreCompact[].hooks[].command' "$SETTINGS")
  [ -n "$cmds" ] || fail "no PreCompact commands found in settings.json"

  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    local script
    script=$(echo "$cmd" | sed -n 's|.*\$HOME/\.claude/hooks/\([A-Za-z0-9._-]*\).*|\1|p')
    [ -n "$script" ] || fail "could not parse script name from command: $cmd"
    [ -f "$REPO_ROOT/claude/hooks/$script" ] \
      || fail "PreCompact references claude/hooks/$script but file is missing"
  done <<< "$cmds"
}

@test "settings.json: precompact.sh registered as synchronous on PreCompact" {
  local async
  async=$(jq -r '.hooks.PreCompact[].hooks[] | select(.command | contains("precompact.sh")) | .async' "$SETTINGS")
  [ "$async" = "false" ] \
    || fail "precompact.sh must be async:false (got: $async); async:true makes decision:block a no-op"
}

@test "precompact emits decision=block JSON on happy path" {
  _run_hook "$PRECOMPACT" '{"session_id":"t","hook_event_name":"PreCompact","trigger":"auto"}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  local decision
  decision=$(echo "$output" | jq -r '.decision')
  [ "$decision" = "block" ] || fail "expected decision=block, got: $decision. output: $output"
  echo "$output" | jq -r '.reason' | grep -q "PATCH" \
    || fail "expected reason to mention PATCH semantics"
}

@test "precompact short-circuits silently when CLAUDE_AUTOMATED=1" {
  export CLAUDE_AUTOMATED=1
  _run_hook "$PRECOMPACT" '{"session_id":"x","hook_event_name":"PreCompact"}'
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status"
  [ -z "$output" ] || fail "expected no stdout when automated, got: $output"
}

@test "precompact survives unset CLAUDE_AUTOMATED under set -u" {
  unset CLAUDE_AUTOMATED
  _run_hook "$PRECOMPACT" '{"session_id":"u","hook_event_name":"PreCompact"}'
  [ "$status" -eq 0 ] \
    || fail "expected exit 0 with unset CLAUDE_AUTOMATED, got $status. output: $output"
}

# ---------------------------------------------------------------------------
# 17-21. smart-checkpoint.sh — milestone detection on Bash|Task PostToolUse
# ---------------------------------------------------------------------------
SMART_CP="$REPO_ROOT/claude/hooks/smart-checkpoint.sh"

@test "settings.json: smart-checkpoint wired on PostToolUse with matcher Bash|Task" {
  local cmd matcher
  matcher=$(jq -r '.hooks.PostToolUse[] | select(.hooks[].command | contains("smart-checkpoint.sh")) | .matcher' "$SETTINGS")
  [ "$matcher" = "Bash|Task" ] || fail "expected matcher=Bash|Task, got: $matcher"
  cmd=$(jq -r '.hooks.PostToolUse[] | select(.hooks[].command | contains("smart-checkpoint.sh")) | .hooks[].command' "$SETTINGS")
  [[ "$cmd" =~ smart-checkpoint\.sh ]] || fail "smart-checkpoint not wired: $cmd"
}

@test "smart-checkpoint detects git push as a milestone" {
  _run_hook "$SMART_CP" '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("git push")' >/dev/null \
    || fail "expected additionalContext mentioning git push, got: $output"
}

@test "smart-checkpoint detects Task completion as a milestone" {
  _run_hook "$SMART_CP" '{"tool_name":"Task","tool_input":{"prompt":"..."}}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("Task")' >/dev/null \
    || fail "expected additionalContext mentioning Task, got: $output"
}

@test "smart-checkpoint stays silent for ordinary Bash commands" {
  _run_hook "$SMART_CP" '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ] || fail "expected no output for non-milestone Bash, got: $output"
}

@test "smart-checkpoint short-circuits when CLAUDE_AUTOMATED=1" {
  export CLAUDE_AUTOMATED=1
  _run_hook "$SMART_CP" '{"tool_name":"Bash","tool_input":{"command":"git push"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ] || fail "expected no output when automated, got: $output"
}

@test "smart-checkpoint detects uv-pytest over bare pytest (case order regression)" {
  # `*"pytest"*` case must come AFTER `*"uv run pytest"*` so the more specific
  # label wins. If someone reorders them, this test fails.
  _run_hook "$SMART_CP" '{"tool_name":"Bash","tool_input":{"command":"uv run pytest tests/"}}'
  [ "$status" -eq 0 ]
  local label
  label=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -oE 'uv pytest run|pytest run' | head -1)
  [ "$label" = "uv pytest run" ] \
    || fail "expected 'uv pytest run' label, got: '$label'"
}
