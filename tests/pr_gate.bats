#!/usr/bin/env bats
# =============================================================================
# pr_gate.bats — Regression tests for claude/hooks/pr-gate.sh
# =============================================================================
# Context: see docs/superpowers/adr/2026-04-20-pre-pr-gate-consistency.md
# These tests exercise each check's failure path to ensure the gate blocks
# (exit 2 + stderr) rather than silently exiting under set -e.

HOOK="$BATS_TEST_DIRNAME/../claude/hooks/pr-gate.sh"

fail() {
  echo "$@" >&2
  return 1
}

# Build a minimal git repo in $1 with arbitrary file contents provided by $2 (path:content pairs)
_make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    # Give origin/HEAD a target so the secrets-scan diff range doesn't crash.
    git commit -q --allow-empty -m "init"
  )
}

_invoke_gate() {
  local cwd="$1"
  echo "{\"tool_input\":{\"command\":\"git push origin main\"},\"cwd\":\"$cwd\"}" \
    | bash "$HOOK"
}

@test "pr-gate blocks on ruff F821 (undefined name)" {
  repo="$BATS_TEST_TMPDIR/f821"
  _make_repo "$repo"
  cat > "$repo/pyproject.toml" <<'EOF'
[project]
name = "test"
version = "0"
EOF
  cat > "$repo/bad.py" <<'EOF'
from __future__ import annotations
def foo(x: Path) -> None:
    return None
EOF
  run _invoke_gate "$repo"
  [ "$status" -eq 2 ] || fail "expected exit 2, got $status. output: $output"
  echo "$output" | grep -q "BLOCKED" || fail "expected BLOCKED in output. got: $output"
  echo "$output" | grep -qi "lint\|F821\|Path" || fail "expected lint mention. got: $output"
}

@test "pr-gate passes on clean Python repo" {
  repo="$BATS_TEST_TMPDIR/clean"
  _make_repo "$repo"
  cat > "$repo/pyproject.toml" <<'EOF'
[project]
name = "test"
version = "0"
EOF
  cat > "$repo/ok.py" <<'EOF'
def foo() -> int:
    return 1
EOF
  run _invoke_gate "$repo"
  [ "$status" -eq 0 ] || fail "expected exit 0, got $status. output: $output"
}

@test "pr-gate does not fire on non-PR, non-push commands" {
  repo="$BATS_TEST_TMPDIR/noop"
  _make_repo "$repo"
  run bash -c "echo '{\"tool_input\":{\"command\":\"ls -la\"},\"cwd\":\"$repo\"}' | bash \"$HOOK\""
  [ "$status" -eq 0 ] || fail "expected exit 0 on non-triggering command, got $status"
}

@test "pr-gate allows worktree branch pushes" {
  repo="$BATS_TEST_TMPDIR/worktree"
  _make_repo "$repo"
  run bash -c "echo '{\"tool_input\":{\"command\":\"git push origin worktree-feature-x\"},\"cwd\":\"$repo\"}' | bash \"$HOOK\""
  [ "$status" -eq 0 ] || fail "expected exit 0 on worktree push, got $status"
}

@test "pr-gate blocks on failing pytest" {
  repo="$BATS_TEST_TMPDIR/pytest-fail"
  _make_repo "$repo"
  cat > "$repo/pyproject.toml" <<'EOF'
[project]
name = "test"
version = "0"
EOF
  mkdir -p "$repo/tests"
  cat > "$repo/tests/test_broken.py" <<'EOF'
def test_fails():
    assert False
EOF
  run _invoke_gate "$repo"
  [ "$status" -eq 2 ] || fail "expected exit 2, got $status. output: $output"
  echo "$output" | grep -q "BLOCKED" || fail "expected BLOCKED. got: $output"
  echo "$output" | grep -qi "test" || fail "expected test mention. got: $output"
}
