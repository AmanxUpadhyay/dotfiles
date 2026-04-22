#!/usr/bin/env bats
# =============================================================================
# safety_guards.bats — regressions for the destructive-command guardrails
# =============================================================================
# Primary concern: the force-push regex was matching "-f" as a substring,
# blocking legitimate pushes to any branch whose name contained "-f" (e.g.
# "feat/observability-foundation"). After the fix, the pattern requires
# whitespace before the flag.

REPO_ROOT="$BATS_TEST_DIRNAME/.."
HOOK="$REPO_ROOT/claude/hooks/safety-guards.sh"

fail() {
  echo "$@" >&2
  return 1
}

_run_with_cmd() {
  local cmd="$1"
  local json
  json=$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}}')
  run bash -c "printf '%s' '$json' | bash '$HOOK'"
}

@test "safety-guards: plain push to a feature branch containing '-f' is allowed" {
  # Regression: branch name "feat/observability-foundation" has "-f" as a
  # substring but isn't the flag. Must not block.
  _run_with_cmd "git push -u origin feat/observability-foundation"
  [ "$status" -eq 0 ] \
    || fail "expected exit 0, got $status. output: $output"
}

@test "safety-guards: real -f flag on git push is blocked" {
  _run_with_cmd "git push -f origin main"
  [ "$status" -ne 0 ] \
    || fail "expected block (non-zero), got 0"
  [[ "$output" == *"Force push prohibited"* ]] \
    || fail "expected 'Force push prohibited' in stderr, got: $output"
}

@test "safety-guards: --force flag is blocked" {
  _run_with_cmd "git push --force origin feature-branch"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Force push prohibited"* ]] \
    || fail "expected block message, got: $output"
}

@test "safety-guards: --force-with-lease is allowed (safer force variant)" {
  _run_with_cmd "git push --force-with-lease origin feature-branch"
  [ "$status" -eq 0 ] \
    || fail "expected exit 0 for --force-with-lease, got $status. output: $output"
}

@test "safety-guards: direct push to main is still blocked" {
  _run_with_cmd "git push origin main"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Direct push to main"* ]] || [[ "$output" == *"main/master"* ]] \
    || fail "expected direct-main block, got: $output"
}
