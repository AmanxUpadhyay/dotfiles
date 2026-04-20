#!/bin/bash
set -euo pipefail
# =============================================================================
# pr-gate.sh — Hard Gate Before PR Creation
# =============================================================================
# purpose: blocks PR creation and remote pushes until ruff format, ruff lint, pytest, secrets scan, and pip-audit all pass
# inputs: stdin JSON with tool_input.command and cwd from PreToolUse event; triggers only on gh pr or git push commands
# outputs: exit 2 with stderr error list if any check fails; exit 0 if all pass
# side-effects: runs ruff, pytest/npm test, pip-audit subprocesses in cwd; reads changed files via git diff
# =============================================================================
# implementation notes:
#   - Every check uses `if ! VAR=$(cmd); then` rather than `VAR=$(cmd); if [ $? -ne 0 ]`.
#     The `$(...)` bare-assignment form combined with `set -e` silently aborts the script
#     on any check failure — see docs/superpowers/adr/2026-04-20-pre-pr-gate-consistency.md
#   - An EXIT trap below converts any unexpected early exit into a loud "INTERNAL ERROR"
#     with blocking exit code 2, so future regressions in the check internals fail loud.

VERDICT_REACHED=0
INTERNAL_ERROR_EXIT_CODE=2
# shellcheck disable=SC2329  # invoked via `trap ... EXIT`, not called directly
_on_exit() {
  local code=$?
  if [ "$code" -ne 0 ] && [ "$VERDICT_REACHED" -eq 0 ]; then
    echo "🚫 PR GATE INTERNAL ERROR: a check aborted before the verdict ran (exit=$code)." >&2
    echo "This is a bug in pr-gate.sh; see docs/superpowers/adr/2026-04-20-pre-pr-gate-consistency.md" >&2
    exit "$INTERNAL_ERROR_EXIT_CODE"
  fi
}
trap _on_exit EXIT

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Belt-and-suspenders guard — sessions where the `if` field in settings.json
# is not yet active will fall through to here. The `if` field prevents the
# process from spawning at all in new sessions; this is the in-session fallback.
if ! echo "$COMMAND" | grep -qE '(gh\s+pr\s+|git\s+push\s+)'; then
  VERDICT_REACHED=1
  exit 0
fi

# Allow pushing to worktree branches (these are intermediate, not PRs)
if echo "$COMMAND" | grep -qE 'git\s+push\s+origin\s+worktree-'; then
  VERDICT_REACHED=1
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
cd "$CWD" 2>/dev/null || { VERDICT_REACHED=1; exit 0; }

ERRORS=""

# --- Check 1: Ruff format ---
if command -v ruff &>/dev/null; then
  if ! ruff format --check . >/dev/null 2>&1; then
    ERRORS="${ERRORS}\n❌ FORMAT: Code is not formatted. Run 'ruff format .' first."
  fi
fi

# --- Check 2: Ruff lint ---
if command -v ruff &>/dev/null; then
  if ! LINT_OUTPUT=$(ruff check . 2>&1); then
    ERRORS="${ERRORS}\n❌ LINT: Ruff found issues:\n$(echo "$LINT_OUTPUT" | head -20)"
  fi
fi

# --- Check 3: Tests ---
if [ -f "package.json" ] && node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts.test ? 0 : 1)" 2>/dev/null; then
  # Node.js project — run npm test
  if ! TEST_OUTPUT=$(npm test 2>&1); then
    ERRORS="${ERRORS}\n❌ TESTS: Tests failed:\n$(echo "$TEST_OUTPUT" | tail -20)"
  fi
elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.cfg" ]; then
  # Python project — run pytest. Accept exit 5 (no tests collected) as non-failure;
  # a repo without tests is a policy question, not a gate failure.
  if command -v uv &>/dev/null; then
    TEST_OUTPUT=$(uv run pytest --tb=short -q 2>&1) && TEST_STATUS=0 || TEST_STATUS=$?
  else
    TEST_OUTPUT=$(pytest --tb=short -q 2>&1) && TEST_STATUS=0 || TEST_STATUS=$?
  fi
  if [ "$TEST_STATUS" -ne 0 ] && [ "$TEST_STATUS" -ne 5 ]; then
    ERRORS="${ERRORS}\n❌ TESTS: Tests failed:\n$(echo "$TEST_OUTPUT" | tail -20)"
  fi
fi

# --- Check 4: Secrets scan ---
# Scan files changed relative to the upstream default branch.
# grep -l exits 1 when no matches found, which is the normal clean case, so we
# treat 1 as success and only 2+ as a real grep error.
REMOTE_DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)
REMOTE_DEFAULT="${REMOTE_DEFAULT:-main}"
CHANGED_FILES=$(git diff --name-only "origin/${REMOTE_DEFAULT}...HEAD" 2>/dev/null || true)
if [ -n "$CHANGED_FILES" ]; then
  SECRET_PATTERNS='(api[_-]?key|api[_-]?secret|access[_-]?token|secret[_-]?key|private[_-]?key|password)\s*[=:]\s*["\x27][A-Za-z0-9+/=_-]{16,}'
  SECRETS_FOUND=$(echo "$CHANGED_FILES" | tr '\n' '\0' | xargs -0 grep -lEi "$SECRET_PATTERNS" 2>/dev/null || true)
  if [ -n "$SECRETS_FOUND" ]; then
    ERRORS="${ERRORS}\n❌ SECRETS: Possible credentials found in:\n$SECRETS_FOUND\nRemove secrets and use environment variables instead."
  fi
fi

# --- Check 5: Dependency security (if pip-audit is available) ---
if command -v pip-audit &>/dev/null; then
  if ! AUDIT_OUTPUT=$(pip-audit --strict 2>&1); then
    ERRORS="${ERRORS}\n❌ SECURITY: pip-audit found vulnerabilities:\n$(echo "$AUDIT_OUTPUT" | head -15)"
  fi
fi

# --- Verdict ---
VERDICT_REACHED=1
if [ -n "$ERRORS" ]; then
  echo "🚫 PR GATE BLOCKED — Fix these issues before creating a PR:" >&2
  echo -e "$ERRORS" >&2
  echo "" >&2
  echo "Run each fix, then retry the PR creation." >&2
  exit 2
fi

exit 0
