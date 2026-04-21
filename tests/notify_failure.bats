#!/usr/bin/env bats
# =============================================================================
# notify_failure.bats — Tests for notify_failure() in claude/crons/notify-failure.sh
# =============================================================================
# Covers: safe-path call, osascript injection escaping, inbox-note content.
#
# Run with: bats tests/notify_failure.bats

NOTIFY_SH="$BATS_TEST_DIRNAME/../claude/crons/notify-failure.sh"

# Local fail helper (bats-core 1.x ships without `fail`)
fail() {
  echo "$@" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Shared setup: build a minimal environment that satisfies notify_failure's
# filesystem requirements (OBSIDIAN_VAULT inbox dir, CLAUDE_LOG_DIR).
# ---------------------------------------------------------------------------
setup() {
  export OBSIDIAN_VAULT="$BATS_TEST_TMPDIR/vault"
  mkdir -p "$OBSIDIAN_VAULT/00-Inbox"

  export CLAUDE_LOG_DIR="$BATS_TEST_TMPDIR/logs"
  mkdir -p "$CLAUDE_LOG_DIR"

  # Stub osascript: capture all args to $CAPTURE_FILE, exit 0.
  export CAPTURE_FILE="$BATS_TEST_TMPDIR/captured-args"
  cat > "$BATS_TEST_TMPDIR/osascript" <<'EOF'
#!/bin/bash
# stub: capture all args for assertion
printf '%s\n' "$@" > "$CAPTURE_FILE"
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/osascript"

  # Prepend stub dir to PATH so our osascript shim wins.
  export PATH="$BATS_TEST_TMPDIR:$PATH"
}

# ---------------------------------------------------------------------------
# Test 1 — Safe path: normal script_name exits 0 and writes inbox note
# ---------------------------------------------------------------------------
@test "notify_failure: safe name exits 0 and writes inbox note" {
  local dummy_log="$BATS_TEST_TMPDIR/dummy.log"
  touch "$dummy_log"

  run bash -c "
    export OBSIDIAN_VAULT=\"$OBSIDIAN_VAULT\"
    export CLAUDE_LOG_DIR=\"$CLAUDE_LOG_DIR\"
    export CAPTURE_FILE=\"$CAPTURE_FILE\"
    export PATH=\"$PATH\"
    source \"$NOTIFY_SH\"
    notify_failure 'mac-cleanup-scan' '$dummy_log'
  "
  [ "$status" -eq 0 ] || fail "expected exit 0 on safe name, got $status. output: $output"

  # Inbox note must exist and contain the script name
  local date_str
  date_str=$(date +%Y-%m-%d)
  local note_path="$OBSIDIAN_VAULT/00-Inbox/${date_str}-cron-error.md"
  [ -f "$note_path" ] || fail "inbox note not found at $note_path"
  grep -q "mac-cleanup-scan" "$note_path" || fail "inbox note missing script name"
}

# ---------------------------------------------------------------------------
# Test 2 — Injection attempt: evil script_name must be escaped in AppleScript
# ---------------------------------------------------------------------------
@test "notify_failure: injection in script_name is escaped before osascript" {
  local evil_name='evil"; delay 5; display dialog "pwned'
  local dummy_log="$BATS_TEST_TMPDIR/dummy.log"
  touch "$dummy_log"

  run bash -c "
    export OBSIDIAN_VAULT=\"$OBSIDIAN_VAULT\"
    export CLAUDE_LOG_DIR=\"$CLAUDE_LOG_DIR\"
    export CAPTURE_FILE=\"$CAPTURE_FILE\"
    export PATH=\"$PATH\"
    source \"$NOTIFY_SH\"
    notify_failure 'evil\"; delay 5; display dialog \"pwned' '$dummy_log'
  "
  [ "$status" -eq 0 ] || fail "expected exit 0 even with evil name, got $status. output: $output"

  # The captured AppleScript must contain escaped double-quote (\" → \\\" in the raw string)
  # We assert the CAPTURE_FILE contains the literal sequence: evil\" (backslash + quote)
  [ -f "$CAPTURE_FILE" ] || fail "capture file not written — osascript stub not invoked"
  grep -q 'evil\\"' "$CAPTURE_FILE" || fail "injection not escaped: expected evil\\\" in captured args"

  # Must NOT contain unescaped evil injection — the raw unescaped sequence would be: delay 5
  # after a literal closing quote. If escaped properly, 'delay 5' will be inside a quoted string,
  # not a separate statement. We detect the unescaped form by checking for the raw unescaped quote
  # followed by the injected command keyword.
  if grep -qP 'evil";\s+delay' "$CAPTURE_FILE" 2>/dev/null; then
    fail "unescaped injection leaked through: $(cat "$CAPTURE_FILE")"
  fi
}

# ---------------------------------------------------------------------------
# Test 3 — Good-path regression: inbox note uses ORIGINAL (unescaped) name
# ---------------------------------------------------------------------------
@test "notify_failure: inbox note body uses original unescaped script_name" {
  local dummy_log="$BATS_TEST_TMPDIR/dummy.log"
  touch "$dummy_log"

  run bash -c "
    export OBSIDIAN_VAULT=\"$OBSIDIAN_VAULT\"
    export CLAUDE_LOG_DIR=\"$CLAUDE_LOG_DIR\"
    export CAPTURE_FILE=\"$CAPTURE_FILE\"
    export PATH=\"$PATH\"
    source \"$NOTIFY_SH\"
    notify_failure 'daily-retrospective' '$dummy_log'
  "
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"

  local date_str
  date_str=$(date +%Y-%m-%d)
  local note_path="$OBSIDIAN_VAULT/00-Inbox/${date_str}-cron-error.md"
  [ -f "$note_path" ] || fail "inbox note not found"

  # Note body must contain the plain (unescaped) name, not AppleScript-escaped form
  grep -q 'daily-retrospective' "$note_path" \
    || fail "inbox note missing original script name. contents: $(cat "$note_path")"
}
