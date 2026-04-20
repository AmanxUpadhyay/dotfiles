#!/usr/bin/env bats
# =============================================================================
# auto_format.bats — Regression tests for claude/hooks/auto-format.sh
# =============================================================================
# Context: see docs/superpowers/adr/2026-04-20-subagent-self-verification.md §
# "Design principles" point 3 — silent code mutation is a bug. When ruff
# --fix removes an unused import, auto-format.sh must surface it as a
# warning (stderr + drift log), not swallow it.

HOOK="$BATS_TEST_DIRNAME/../claude/hooks/auto-format.sh"

fail() {
  echo "$@" >&2
  return 1
}

setup() {
  export AUTO_FORMAT_DRIFT_LOG="$BATS_TEST_TMPDIR/drift.log"
}

_invoke_write() {
  local file_path="$1"
  echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$file_path\"}}" | bash "$HOOK"
}

_invoke_edit() {
  local file_path="$1"
  echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$file_path\"}}" | bash "$HOOK"
}

_invoke_multiedit() {
  local file_a="$1"
  local file_b="$2"
  echo "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"edits\":[{\"file_path\":\"$file_a\"},{\"file_path\":\"$file_b\"}]}}" | bash "$HOOK"
}

@test "auto-format warns on stderr when ruff removes an unused import" {
  target="$BATS_TEST_TMPDIR/dirty.py"
  cat > "$target" <<'EOF'
import os
def foo() -> int:
    return 1
EOF
  run _invoke_write "$target"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  echo "$output" | grep -q "auto-format: removed unused import" \
    || fail "expected stderr warning. got: $output"
  echo "$output" | grep -q "dirty.py" \
    || fail "expected warning to name the file. got: $output"
}

@test "auto-format writes drift log entry on import removal" {
  target="$BATS_TEST_TMPDIR/dirty2.py"
  cat > "$target" <<'EOF'
import sys
def bar() -> int:
    return 2
EOF
  _invoke_write "$target"
  [ -f "$AUTO_FORMAT_DRIFT_LOG" ] \
    || fail "expected drift log at $AUTO_FORMAT_DRIFT_LOG"
  grep -q "dirty2.py" "$AUTO_FORMAT_DRIFT_LOG" \
    || fail "expected drift log to mention dirty2.py. contents:\n$(cat "$AUTO_FORMAT_DRIFT_LOG")"
}

@test "auto-format stays quiet on a clean file" {
  target="$BATS_TEST_TMPDIR/clean.py"
  cat > "$target" <<'EOF'
def baz() -> int:
    return 3
EOF
  run _invoke_write "$target"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  if echo "$output" | grep -q "auto-format: removed unused import"; then
    fail "did not expect warning on clean file. got: $output"
  fi
}

@test "auto-format ignores non-Python files (preserves existing behaviour)" {
  target="$BATS_TEST_TMPDIR/notes.txt"
  echo "hello" > "$target"
  run _invoke_write "$target"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status"
  [ "$(cat "$target")" = "hello" ] || fail "file was modified"
}

@test "auto-format handles MultiEdit: warns only for the dirty file" {
  dirty="$BATS_TEST_TMPDIR/multi_dirty.py"
  clean="$BATS_TEST_TMPDIR/multi_clean.py"
  cat > "$dirty" <<'EOF'
import json
def one() -> int:
    return 1
EOF
  cat > "$clean" <<'EOF'
def two() -> int:
    return 2
EOF
  run _invoke_multiedit "$dirty" "$clean"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
  echo "$output" | grep -q "multi_dirty.py" \
    || fail "expected warning for dirty file. got: $output"
  if echo "$output" | grep -q "multi_clean.py.*removed unused import"; then
    fail "did not expect warning for clean file"
  fi
}

@test "auto-format still applies the fix (behaviour preserved)" {
  target="$BATS_TEST_TMPDIR/still_fixed.py"
  cat > "$target" <<'EOF'
import os
def q() -> int:
    return 4
EOF
  _invoke_write "$target"
  # After the hook, the unused import should be gone.
  if grep -q "^import os" "$target"; then
    fail "expected unused 'import os' to be removed by ruff --fix. file:\n$(cat "$target")"
  fi
}

@test "auto-format missing file_path is a no-op" {
  run bash -c "echo '{\"tool_name\":\"Write\",\"tool_input\":{}}' | bash \"$HOOK\""
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
}
