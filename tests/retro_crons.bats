#!/usr/bin/env bats
# =============================================================================
# retro_crons.bats — Guards against GNU `timeout` regressions in retro/weekly crons
# =============================================================================
# The retro/weekly cron scripts must not invoke GNU `timeout` because macOS
# ships without it. They must use the `bash_timeout` helper from env.sh instead.
# See PR #122 (env.sh) and PR #124 (healthcheck.sh) for prior fixes.
#
# Run with: bats tests/retro_crons.bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."

fail() {
  echo "$@" >&2
  return 1
}

@test "retro/weekly crons: no GNU timeout invocations remain" {
  local scripts=(
    "$REPO_ROOT/claude/crons/daily-retro-evening.sh"
    "$REPO_ROOT/claude/crons/daily-retrospective.sh"
    "$REPO_ROOT/claude/crons/weekly-finalize.sh"
    "$REPO_ROOT/claude/crons/weekly-report-gen.sh"
  )
  for f in "${scripts[@]}"; do
    [[ -f "$f" ]] || fail "script missing: $f"
    if grep -qE '^[[:space:]]*timeout[[:space:]]' "$f"; then
      fail "GNU timeout remains in $f"
    fi
  done
}

@test "retro/weekly crons: each uses bash_timeout helper" {
  local scripts=(
    "$REPO_ROOT/claude/crons/daily-retro-evening.sh"
    "$REPO_ROOT/claude/crons/daily-retrospective.sh"
    "$REPO_ROOT/claude/crons/weekly-finalize.sh"
    "$REPO_ROOT/claude/crons/weekly-report-gen.sh"
  )
  for f in "${scripts[@]}"; do
    grep -qE '\bbash_timeout[[:space:]]+[0-9]+' "$f" \
      || fail "bash_timeout not used in $f"
  done
}
