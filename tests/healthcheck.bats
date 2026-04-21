#!/usr/bin/env bats
# =============================================================================
# healthcheck.bats — Regression tests for claude/crons/healthcheck.sh
# =============================================================================
# Covers:
#   1. Empty errors[] array doesn't crash under set -u (Bug 2 regression)
#   2. Lock contention — second invocation exits 0 with "already running"
#   3. flock/timeout not present in the script (enforcement of Bug 1 + 3 fixes)
#
# Run with: bats tests/healthcheck.bats

HEALTHCHECK="$BATS_TEST_DIRNAME/../claude/crons/healthcheck.sh"
ENV_SH="$BATS_TEST_DIRNAME/../claude/env.sh"
NOTIFY_SH="$BATS_TEST_DIRNAME/../claude/crons/notify-failure.sh"

# Local fail helper (bats-core 1.x ships without `fail`)
fail() {
  echo "$@" >&2
  return 1
}

# ---------------------------------------------------------------------------
# Shared setup: build a minimal environment that satisfies all preflight
# checks so the healthcheck can complete without crashing mid-run.
# ---------------------------------------------------------------------------
setup() {
  # Vault structure
  export OBSIDIAN_VAULT="$BATS_TEST_TMPDIR/vault"
  mkdir -p "$OBSIDIAN_VAULT/07-Daily"
  mkdir -p "$OBSIDIAN_VAULT/00-Inbox"
  # Create critical vault dirs that preflight verifies
  local vault_dirs=(
    "01-LXS/Decisions"
    "01-LXS/reports/weekly"
    "02-Startups/AdTecher/Decisions"
    "02-Startups/AdTecher/reports/weekly"
    "02-Startups/Ledgx/reports/weekly"
    "03-Clients/ClubRevAI/reports/weekly"
    "03-Clients/Wayv Telcom/reports/weekly"
    "06-Sessions/Personal"
    "06-Sessions/LXS"
    "07-Daily"
  )
  for vdir in "${vault_dirs[@]}"; do
    mkdir -p "$OBSIDIAN_VAULT/$vdir"
  done

  # Create yesterday's daily note so postrun check passes
  local yesterday
  yesterday=$(date -v-1d +%Y-%m-%d)
  touch "$OBSIDIAN_VAULT/07-Daily/${yesterday}.md"

  # ORG_MAP
  export ORG_MAP="$BATS_TEST_TMPDIR/org-map.json"
  echo '{}' > "$ORG_MAP"

  # Log dir
  export CLAUDE_LOG_DIR="$BATS_TEST_TMPDIR/logs"
  mkdir -p "$CLAUDE_LOG_DIR"

  # CLAUDE_BIN stub — fast, exit 0
  local stub_bin="$BATS_TEST_TMPDIR/bin/claude"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/bash\necho "claude 1.0 (stub)"\nexit 0\n' > "$stub_bin"
  chmod +x "$stub_bin"
  export CLAUDE_BIN="$stub_bin"

  # Prompt templates (preflight checks for these)
  local prompts_dir="$BATS_TEST_TMPDIR/prompts"
  mkdir -p "$prompts_dir"
  for tmpl in daily-retrospective daily-retro-evening weekly-report-gen weekly-finalize; do
    touch "$prompts_dir/$tmpl.md"
  done

  # Stub npx so preflight's `command -v npx` succeeds
  local stub_npx="$BATS_TEST_TMPDIR/bin/npx"
  printf '#!/bin/bash\nexit 0\n' > "$stub_npx"
  chmod +x "$stub_npx"

  # Stub osascript so notify_failure doesn't pop real OS dialogs
  local stub_osa="$BATS_TEST_TMPDIR/bin/osascript"
  printf '#!/bin/bash\nexit 0\n' > "$stub_osa"
  chmod +x "$stub_osa"

  # Stub pgrep to always report Claude Desktop as running
  local stub_pgrep="$BATS_TEST_TMPDIR/bin/pgrep"
  printf '#!/bin/bash\nexit 0\n' > "$stub_pgrep"
  chmod +x "$stub_pgrep"

  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"

  # Use a unique lockfile per test run to avoid cross-test interference
  export HEALTHCHECK_LOCK="$BATS_TEST_TMPDIR/healthcheck-$BATS_TEST_NUMBER.lock"
}

# ---------------------------------------------------------------------------
# Helper: run healthcheck with all env overrides injected
# Healthcheck sources env.sh (which resets paths) so we pass vars explicitly.
# We also patch PROMPTS_DIR and the lock path via env override.
# ---------------------------------------------------------------------------
_run_healthcheck() {
  local mode="${1:-both}"
  local prompts_dir="$BATS_TEST_TMPDIR/prompts"
  run env \
    OBSIDIAN_VAULT="$OBSIDIAN_VAULT" \
    ORG_MAP="$ORG_MAP" \
    CLAUDE_LOG_DIR="$CLAUDE_LOG_DIR" \
    CLAUDE_BIN="$CLAUDE_BIN" \
    HEALTHCHECK_LOCK="$HEALTHCHECK_LOCK" \
    PATH="$PATH" \
    bash -c "
      # Patch healthcheck to use stub prompts dir and our lock path
      sed \
        -e 's|PROMPTS_DIR=\"\$HOME/.dotfiles/claude/prompts\"|PROMPTS_DIR=\"$prompts_dir\"|g' \
        -e 's|/tmp/claude-healthcheck.lock|\$HEALTHCHECK_LOCK|g' \
        \"$HEALTHCHECK\" > \"$BATS_TEST_TMPDIR/healthcheck-patched.sh\"
      chmod +x \"$BATS_TEST_TMPDIR/healthcheck-patched.sh\"
      exec bash \"$BATS_TEST_TMPDIR/healthcheck-patched.sh\" \"$mode\"
    "
}

# ---------------------------------------------------------------------------
# Test 1 — Empty errors[] array doesn't crash under set -u
# Stub all preflight deps so run_preflight passes cleanly (no errors to add),
# then verify postrun also passes. Exit 0 means no unbound variable crash.
# ---------------------------------------------------------------------------
@test "healthcheck: empty errors array doesn't crash under set -u" {
  _run_healthcheck "preflight"
  [ "$status" -eq 0 ] || fail "expected exit 0 (no unbound variable crash), got $status. output: $output"
}

# ---------------------------------------------------------------------------
# Test 2 — Lock contention: second invocation exits 0 with "already running"
# Pre-create the lockfile with a live PID to simulate a running instance.
# ---------------------------------------------------------------------------
@test "healthcheck: second invocation exits 0 when lock is held" {
  # Write our own PID to the lock file — shlock format is just the PID
  echo "$$" > "$HEALTHCHECK_LOCK"

  # On macOS, shlock -p PID -f FILE reclaims the lock only if the PID is dead.
  # Since $$ (the bats shell) is alive, the lock should be held.
  # However, shlock's liveness check uses kill -0 which works for same-user PIDs.
  # Write using shlock itself so the file is in proper shlock format:
  /usr/bin/shlock -p "$$" -f "$HEALTHCHECK_LOCK" || true

  local prompts_dir="$BATS_TEST_TMPDIR/prompts"
  run env \
    OBSIDIAN_VAULT="$OBSIDIAN_VAULT" \
    ORG_MAP="$ORG_MAP" \
    CLAUDE_LOG_DIR="$CLAUDE_LOG_DIR" \
    CLAUDE_BIN="$CLAUDE_BIN" \
    HEALTHCHECK_LOCK="$HEALTHCHECK_LOCK" \
    PATH="$PATH" \
    bash -c "
      sed \
        -e 's|PROMPTS_DIR=\"\$HOME/.dotfiles/claude/prompts\"|PROMPTS_DIR=\"$prompts_dir\"|g' \
        -e 's|/tmp/claude-healthcheck.lock|\$HEALTHCHECK_LOCK|g' \
        \"$HEALTHCHECK\" > \"$BATS_TEST_TMPDIR/healthcheck-patched-lock.sh\"
      chmod +x \"$BATS_TEST_TMPDIR/healthcheck-patched-lock.sh\"
      exec bash \"$BATS_TEST_TMPDIR/healthcheck-patched-lock.sh\" preflight
    "
  [ "$status" -eq 0 ] || fail "expected exit 0 (lock skip), got $status. output: $output"
  echo "$output" | grep -qi "already running\|skipping" \
    || fail "expected 'already running' message, got: $output"
}

# ---------------------------------------------------------------------------
# Test 3 — flock and timeout are NOT present in healthcheck.sh
# This enforces that Bug 1 and Bug 3 fixes remain in place.
# ---------------------------------------------------------------------------
@test "healthcheck: script does not call flock or GNU timeout" {
  # flock must not appear as an executable call (non-comment lines only)
  # Comments explaining the replacement are fine; actual calls are not.
  ! grep -vE '^\s*#' "$HEALTHCHECK" | grep -qE '\bflock\b' \
    || fail "flock called in healthcheck.sh — Bug 1 fix has regressed"

  # GNU-style `timeout <duration>` (e.g. `timeout 10s` or `timeout 10`)
  # must not appear in non-comment lines
  ! grep -vE '^\s*#' "$HEALTHCHECK" | grep -qE '\btimeout\s+[0-9]' \
    || fail "'timeout <N>' called in healthcheck.sh — Bug 3 fix has regressed"
}
