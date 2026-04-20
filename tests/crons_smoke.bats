#!/usr/bin/env bats
# =============================================================================
# crons_smoke.bats — Smoke tests for claude/crons scripts
# =============================================================================
# Run with: bats tests/crons_smoke.bats

DOTFILES="$BATS_TEST_DIRNAME/.."

# Local fail helper — bats-core 1.x ships without `fail`; bats-assert would add a
# submodule dependency that isn't worth it for ten smoke assertions.
fail() {
  echo "$@" >&2
  return 1
}

@test "healthcheck.sh is executable" {
  [ -x "$DOTFILES/claude/crons/healthcheck.sh" ]
}

@test "notify-failure.sh is executable" {
  [ -x "$DOTFILES/claude/crons/notify-failure.sh" ]
}

@test "log-rotate.sh is executable" {
  [ -x "$DOTFILES/claude/crons/log-rotate.sh" ]
}

@test "daily-retrospective.sh is executable" {
  [ -x "$DOTFILES/claude/crons/daily-retrospective.sh" ]
}

@test "weekly-report-gen.sh is executable" {
  [ -x "$DOTFILES/claude/crons/weekly-report-gen.sh" ]
}

@test "all cron scripts have duration_ms marker" {
  for script in "$DOTFILES"/claude/crons/*.sh; do
    run grep -q "duration_ms" "$script"
    [ "$status" -eq 0 ] || fail "Missing duration_ms in $script"
  done
}

# Regression tests for 2026-04-20 review fixes.

@test "claude-mem-worker: success marker touched after bun runs, not before" {
  script="$DOTFILES/claude/crons/claude-mem-worker.sh"
  bun_line=$(grep -n '"\$BUN" "\$WORKER"' "$script" | head -1 | cut -d: -f1)
  touch_line=$(grep -nE '^[[:space:]]*touch .*\.last-success-claude-mem-worker' "$script" | head -1 | cut -d: -f1)
  [ -n "$bun_line" ] || fail "bun invocation line not found"
  [ -n "$touch_line" ] || fail "last-success touch not found"
  [ "$bun_line" -lt "$touch_line" ] || fail "marker touched at line $touch_line before bun at line $bun_line"
}

@test "claude-mem-worker: does not use exec for the worker process" {
  script="$DOTFILES/claude/crons/claude-mem-worker.sh"
  run grep -qE '^\s*exec\s+"\$BUN"' "$script"
  [ "$status" -ne 0 ] || fail "exec on \$BUN prevents exit-status observation"
}

@test "notify-failure: notify_sent status, not ok, to avoid metric collision" {
  script="$DOTFILES/claude/crons/notify-failure.sh"
  run grep -qE 'status=notify_sent' "$script"
  [ "$status" -eq 0 ] || fail "Expected status=notify_sent marker in notify-failure.sh"
  if grep -vE '^[[:space:]]*#' "$script" | grep -qE 'status=ok'; then
    fail "status=ok inside notify_failure causes last-line-wins metric flip"
  fi
}

@test "stop-notification: no unsafe \$PROJECT interpolation in osascript -e" {
  script="$DOTFILES/claude/hooks/stop-notification.sh"
  run grep -qE 'osascript -e .*\$PROJECT' "$script"
  [ "$status" -ne 0 ] || fail "\$PROJECT interpolated into osascript -e — AppleScript injection risk"
  run grep -qE 'osascript - "\$PROJECT"' "$script"
  [ "$status" -eq 0 ] || fail "Expected argv-pattern osascript invocation for \$PROJECT"
}
