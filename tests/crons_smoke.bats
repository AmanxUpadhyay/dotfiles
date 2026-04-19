#!/usr/bin/env bats
# =============================================================================
# crons_smoke.bats — Smoke tests for claude/crons scripts
# =============================================================================
# Run with: bats tests/crons_smoke.bats

DOTFILES="$BATS_TEST_DIRNAME/.."

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
