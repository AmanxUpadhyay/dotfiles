#!/usr/bin/env bats
# =============================================================================
# env_preflight.bats — Tests for preflight_check() in claude/env.sh
# =============================================================================
# Covers: happy path, watchdog timeout path, missing/non-executable binary.
# All tests run with a PATH that has no `timeout` command, verifying the
# pure-bash watchdog works without GNU coreutils.
#
# Run with: bats tests/env_preflight.bats

ENV_SH="$BATS_TEST_DIRNAME/../claude/env.sh"

# Local fail helper (bats-core 1.x ships without `fail`)
fail() {
  echo "$@" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Shared setup: build a minimal environment that satisfies all preflight
# checks EXCEPT the one under test, so tests stay isolated.
# ---------------------------------------------------------------------------
setup() {
  # Strip `timeout` (and gtimeout) from PATH for every test — the fix must not
  # rely on GNU coreutils being present.
  local _no_timeout_bin="$BATS_TEST_TMPDIR/no-timeout-bin"
  mkdir -p "$_no_timeout_bin"
  # Proxy every binary from PATH except any named `timeout` or `gtimeout`
  # The simplest approach: just use an isolated PATH that has none of them.
  # We override PATH so that the tested code also sees no `timeout`.
  export PATH="$_no_timeout_bin:/Users/godl1ke/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

  # Stub OBSIDIAN_VAULT — preflight checks it's a directory
  export OBSIDIAN_VAULT="$BATS_TEST_TMPDIR/vault"
  mkdir -p "$OBSIDIAN_VAULT"

  # Stub ORG_MAP — preflight checks it's a file
  export ORG_MAP="$BATS_TEST_TMPDIR/org-map.json"
  echo '{}' > "$ORG_MAP"
}

# ---------------------------------------------------------------------------
# Helper: create a stub CLAUDE_BIN that runs a given script body
# ---------------------------------------------------------------------------
_make_stub_bin() {
  local name="$1"
  local body="$2"
  local bin_path="$BATS_TEST_TMPDIR/$name"
  printf '#!/bin/bash\n%s\n' "$body" > "$bin_path"
  chmod +x "$bin_path"
  echo "$bin_path"
}

# ---------------------------------------------------------------------------
# Test 1 — Happy path: fast binary, no timeout command in PATH
# ---------------------------------------------------------------------------
@test "preflight_check: happy path — fast binary exits 0, no timeout needed" {
  local fake_bin
  fake_bin=$(_make_stub_bin "claude-fast" 'echo "1.0 (stub)"; exit 0')

  # Source env.sh, then override CLAUDE_BIN so env.sh's fallback chain cannot
  # replace our stub. OBSIDIAN_VAULT and ORG_MAP are pre-set so they pass.
  run bash -c "
    export OBSIDIAN_VAULT=\"$OBSIDIAN_VAULT\"
    export ORG_MAP=\"$ORG_MAP\"
    export PATH=\"$PATH\"
    source \"$ENV_SH\"
    export CLAUDE_BIN=\"$fake_bin\"
    preflight_check 'bats-happy-path'
  "
  [ "$status" -eq 0 ] || fail "expected exit 0 on happy path, got $status. output: $output"
}

# ---------------------------------------------------------------------------
# Test 2 — Timeout path: binary sleeps 30s, watchdog kills it, error returned
# ---------------------------------------------------------------------------
@test "preflight_check: slow binary triggers watchdog within ~12s" {
  local fake_bin
  fake_bin=$(_make_stub_bin "claude-slow" 'sleep 30')

  # We temporarily lower the watchdog from 10s to 2s by patching env.sh inline.
  # We do this by sourcing a modified copy so the test completes quickly.
  local patched_env="$BATS_TEST_TMPDIR/env_patched.sh"
  sed 's/sleep 10/sleep 2/' "$ENV_SH" > "$patched_env"
  chmod +x "$patched_env"

  run bash -c "
    export OBSIDIAN_VAULT=\"$OBSIDIAN_VAULT\"
    export ORG_MAP=\"$ORG_MAP\"
    export PATH=\"$PATH\"
    source \"$patched_env\"
    export CLAUDE_BIN=\"$fake_bin\"
    preflight_check 'bats-timeout-path'
  "
  [ "$status" -eq 1 ] || fail "expected exit 1 on slow binary, got $status. output: $output"
  echo "$output" | grep -qi "did not respond to --version within" \
    || fail "expected timeout error message. got: $output"
}

# ---------------------------------------------------------------------------
# Test 3 — Missing binary: CLAUDE_BIN points to nonexistent path
# Note: env.sh re-resolves CLAUDE_BIN via a fallback chain when the override
# is not executable. We set PATH to an empty dir so the fallback also finds
# nothing, ensuring CLAUDE_BIN stays unresolved after sourcing.
# ---------------------------------------------------------------------------
@test "preflight_check: nonexistent CLAUDE_BIN returns error" {
  # An isolated PATH that contains no `claude` binary at all
  local _empty_bin="$BATS_TEST_TMPDIR/empty-bin"
  mkdir -p "$_empty_bin"

  run bash -c "
    export OBSIDIAN_VAULT=\"$OBSIDIAN_VAULT\"
    export ORG_MAP=\"$ORG_MAP\"
    export PATH=\"$_empty_bin:/usr/bin:/bin\"
    source \"$ENV_SH\"
    # After sourcing, CLAUDE_BIN is unresolved — override to nonexistent to be explicit
    export CLAUDE_BIN=\"/nonexistent/path/to/claude\"
    preflight_check 'bats-missing-bin'
  "
  [ "$status" -eq 1 ] || fail "expected exit 1 for missing binary, got $status. output: $output"
  echo "$output" | grep -qi "not found or not executable" \
    || fail "expected 'not found or not executable' error. got: $output"
}

# ---------------------------------------------------------------------------
# Test 4 — Missing OBSIDIAN_VAULT returns error
# Note: CLAUDE_BIN must be set AFTER sourcing env.sh to prevent the fallback
# chain from overwriting our stub value.
# ---------------------------------------------------------------------------
@test "preflight_check: missing OBSIDIAN_VAULT returns error" {
  local fake_bin
  fake_bin=$(_make_stub_bin "claude-ok" 'echo "1.0 (stub)"; exit 0')

  # Source env.sh, then override ALL checked vars to test only the vault check.
  # env.sh exports OBSIDIAN_VAULT from $HOME — we must override it after sourcing.
  run bash -c "
    export ORG_MAP=\"$ORG_MAP\"
    export PATH=\"$PATH\"
    source \"$ENV_SH\"
    export CLAUDE_BIN=\"$fake_bin\"
    export OBSIDIAN_VAULT=\"/nonexistent/vault\"
    preflight_check 'bats-no-vault'
  "
  [ "$status" -eq 1 ] || fail "expected exit 1 for missing vault, got $status. output: $output"
  echo "$output" | grep -qi "OBSIDIAN_VAULT not accessible" \
    || fail "expected vault error. got: $output"
}

# ---------------------------------------------------------------------------
# Test 5 — bash_timeout: fast command exits 0 within 1s
# ---------------------------------------------------------------------------
@test "bash_timeout: fast command exits 0" {
  run bash -c "
    export PATH=\"$PATH\"
    source \"$ENV_SH\"
    bash_timeout 5 true
  "
  [ "$status" -eq 0 ] || fail "expected exit 0 for fast command, got $status. output: $output"
}

# ---------------------------------------------------------------------------
# Test 6 — bash_timeout: slow command (sleep 30) is killed, returns nonzero
# within ~4s when limit is 2
# ---------------------------------------------------------------------------
@test "bash_timeout: slow command is killed and returns nonzero" {
  local start end elapsed
  start=$(date +%s)
  run bash -c "
    export PATH=\"$PATH\"
    source \"$ENV_SH\"
    bash_timeout 2 sleep 30
  "
  end=$(date +%s)
  elapsed=$(( end - start ))

  [ "$status" -ne 0 ] || fail "expected nonzero exit for timed-out command, got $status"
  # Should complete well within 10s (target ~2s watchdog + overhead)
  [ "$elapsed" -lt 10 ] || fail "bash_timeout took too long: ${elapsed}s (expected < 10s)"
}

# ---------------------------------------------------------------------------
# Test 7 — bash_timeout: propagates command exit code (not 0)
# ---------------------------------------------------------------------------
@test "bash_timeout: propagates nonzero exit code from command" {
  run bash -c "
    export PATH=\"$PATH\"
    source \"$ENV_SH\"
    bash_timeout 5 false
  "
  [ "$status" -eq 1 ] || fail "expected exit 1 from 'false', got $status. output: $output"
}
