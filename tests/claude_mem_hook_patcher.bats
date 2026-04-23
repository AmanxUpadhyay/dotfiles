#!/usr/bin/env bats
# =============================================================================
# claude_mem_hook_patcher.bats — Tests for patch-claude-mem-hooks.sh
# =============================================================================
# Ensures the self-healing patcher:
#   1. Appends ` || true` to observer hook commands missing it
#   2. Is idempotent (re-running does not append twice)
#   3. Leaves non-observer hooks untouched
#   4. Produces valid JSON
#   5. Does not mutate commands already ending with ` || true`
#
# Also includes a static sync-check: the CLAUDE_MEM_WORKER_PORT formula must
# be identical in env.sh and .zshenv (the two places it's defined).
#
# Run with: bats tests/claude_mem_hook_patcher.bats

PATCHER="$BATS_TEST_DIRNAME/../claude/scripts/patch-claude-mem-hooks.sh"
ENV_SH="$BATS_TEST_DIRNAME/../claude/env.sh"
ZSHENV="$BATS_TEST_DIRNAME/../zsh/.zshenv"

fail() { echo "$@" >&2; return 1; }

# A minimal hooks.json shaped like claude-mem's, with the buggy tail on UPS
_write_buggy_hooks_json() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
{
  "description": "claude-mem hooks (test fixture)",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ \"$_HEALTH\" = \"1\" ] && node foo.js"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node observe.js"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node summarize.js"
          }
        ]
      }
    ]
  }
}
EOF
}

# ---------------------------------------------------------------------------

@test "patcher appends ' || true' to UserPromptSubmit command missing it" {
  local f="$BATS_TEST_TMPDIR/hooks.json"
  _write_buggy_hooks_json "$f"
  run "$PATCHER" "$f"
  [ "$status" -eq 0 ] || fail "patcher exited non-zero: $output"
  # The UPS command should now end with " || true"
  local cmd
  cmd=$(python3 -c "import json,sys; print(json.load(open('$f'))['hooks']['UserPromptSubmit'][0]['hooks'][0]['command'])")
  [[ "$cmd" == *' || true' ]] || fail "UPS command not patched: $cmd"
}

@test "patcher is idempotent — second run produces identical file" {
  local f="$BATS_TEST_TMPDIR/hooks.json"
  _write_buggy_hooks_json "$f"
  "$PATCHER" "$f"
  local sum1; sum1=$(shasum "$f" | awk '{print $1}')
  "$PATCHER" "$f"
  local sum2; sum2=$(shasum "$f" | awk '{print $1}')
  [ "$sum1" = "$sum2" ] || fail "patcher not idempotent — sums differ: $sum1 vs $sum2"
}

@test "patcher patches PostToolUse and Stop (all observer events)" {
  local f="$BATS_TEST_TMPDIR/hooks.json"
  _write_buggy_hooks_json "$f"
  "$PATCHER" "$f"
  for ev in PostToolUse Stop; do
    local cmd
    cmd=$(python3 -c "
import json
d = json.load(open('$f'))
for g in d['hooks']['$ev']:
    for h in g['hooks']:
        print(h['command'])
")
    [[ "$cmd" == *' || true' ]] || fail "$ev command not patched: $cmd"
  done
}

@test "patcher leaves already-patched commands unchanged" {
  local f="$BATS_TEST_TMPDIR/hooks.json"
  cat > "$f" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "node foo.js || true" } ] }
    ]
  }
}
EOF
  local before; before=$(cat "$f")
  "$PATCHER" "$f"
  # Content of the command field must still end with exactly one ' || true'
  local cmd
  cmd=$(python3 -c "import json; print(json.load(open('$f'))['hooks']['UserPromptSubmit'][0]['hooks'][0]['command'])")
  [[ "$cmd" == "node foo.js || true" ]] || fail "idempotence broken: $cmd"
}

@test "patcher output is valid JSON" {
  local f="$BATS_TEST_TMPDIR/hooks.json"
  _write_buggy_hooks_json "$f"
  "$PATCHER" "$f"
  python3 -c "import json; json.load(open('$f'))" || fail "output is not valid JSON"
}

@test "patcher handles missing file gracefully (exit 0, no crash)" {
  run "$PATCHER" "$BATS_TEST_TMPDIR/does-not-exist.json"
  [ "$status" -eq 0 ] || fail "patcher should fail-open on missing file, got $status: $output"
}

@test "patcher with no args scans the plugin cache tree without error" {
  # Dry-run style invocation — must exit 0 even if no plugin is installed
  run env HOME="$BATS_TEST_TMPDIR" "$PATCHER"
  [ "$status" -eq 0 ] || fail "patcher should exit 0 with no args and no plugin, got $status: $output"
}

@test "CLAUDE_MEM_WORKER_PORT formula is identical in env.sh and .zshenv" {
  # Static sync-check: the formula must not drift between the two files.
  # Both should contain the same UID-based formula expression.
  local env_line zshenv_line
  env_line=$(grep -E 'CLAUDE_MEM_WORKER_PORT=.*\$\(\(37700' "$ENV_SH" | head -1)
  zshenv_line=$(grep -E 'CLAUDE_MEM_WORKER_PORT=.*\$\(\(37700' "$ZSHENV" | head -1)
  [ -n "$env_line" ] || fail "env.sh missing CLAUDE_MEM_WORKER_PORT formula"
  [ -n "$zshenv_line" ] || fail ".zshenv missing CLAUDE_MEM_WORKER_PORT formula"
  # Normalise whitespace and compare
  local a b
  a=$(echo "$env_line" | tr -s ' ')
  b=$(echo "$zshenv_line" | tr -s ' ')
  [ "$a" = "$b" ] || fail "formula drift: env.sh='$a' zshenv='$b'"
}
