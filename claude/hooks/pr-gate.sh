#!/bin/bash
# =============================================================================
# GODL1KE pr-gate.sh — Hard Gate Before PR Creation
# =============================================================================
# WHY: This is your quality firewall. Before Claude can create a PR or push
# to a remote branch, this hook runs:
#   1. Ruff format check (is code formatted?)
#   2. Ruff lint check (are there lint errors?)
#   3. pytest (do tests pass?)
#   4. Secrets scan (are there leaked credentials?)
#   5. pip-audit (are there known vulnerabilities?)
#
# ALL checks must pass. If ANY fail, the PR/push is BLOCKED (exit 2).
# This ensures every PR is code-reviewed and security-scanned automatically.
#
# Location: ~/.claude/hooks/pr-gate.sh
# Triggered by: PreToolUse → Bash (only activates for PR/push commands)
# =============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Belt-and-suspenders guard — sessions where the `if` field in settings.json
# is not yet active will fall through to here. The `if` field prevents the
# process from spawning at all in new sessions; this is the in-session fallback.
if ! echo "$COMMAND" | grep -qE '(gh\s+pr\s+|git\s+push\s+)'; then
  exit 0
fi

# Allow pushing to worktree branches (these are intermediate, not PRs)
if echo "$COMMAND" | grep -qE 'git\s+push\s+origin\s+worktree-'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
cd "$CWD" 2>/dev/null || exit 0

ERRORS=""

# --- Check 1: Ruff format ---
if command -v ruff &>/dev/null; then
  if ! ruff format --check . 2>/dev/null; then
    ERRORS="${ERRORS}\n❌ FORMAT: Code is not formatted. Run 'ruff format .' first."
  fi
fi

# --- Check 2: Ruff lint ---
if command -v ruff &>/dev/null; then
  LINT_OUTPUT=$(ruff check . 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}\n❌ LINT: Ruff found issues:\n$(echo "$LINT_OUTPUT" | head -20)"
  fi
fi

# --- Check 3: Tests ---
if [ -f "package.json" ] && node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts.test ? 0 : 1)" 2>/dev/null; then
  # Node.js project — run npm test
  TEST_OUTPUT=$(npm test 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}\n❌ TESTS: Tests failed:\n$(echo "$TEST_OUTPUT" | tail -20)"
  fi
elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.cfg" ]; then
  # Python project — run pytest
  if command -v uv &>/dev/null; then
    TEST_OUTPUT=$(uv run pytest --tb=short -q 2>&1)
  else
    TEST_OUTPUT=$(pytest --tb=short -q 2>&1)
  fi
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}\n❌ TESTS: Tests failed:\n$(echo "$TEST_OUTPUT" | tail -20)"
  fi
fi

# --- Check 4: Secrets scan ---
# Scan files changed relative to the upstream default branch
REMOTE_DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
REMOTE_DEFAULT="${REMOTE_DEFAULT:-main}"
CHANGED_FILES=$(git diff --name-only "origin/${REMOTE_DEFAULT}...HEAD" 2>/dev/null)
if [ -n "$CHANGED_FILES" ]; then
  SECRET_PATTERNS='(api[_-]?key|api[_-]?secret|access[_-]?token|secret[_-]?key|private[_-]?key|password)\s*[=:]\s*["\x27][A-Za-z0-9+/=_-]{16,}'
  SECRETS_FOUND=$(echo "$CHANGED_FILES" | tr '\n' '\0' | xargs -0 grep -lEi "$SECRET_PATTERNS" 2>/dev/null)
  if [ -n "$SECRETS_FOUND" ]; then
    ERRORS="${ERRORS}\n❌ SECRETS: Possible credentials found in:\n$SECRETS_FOUND\nRemove secrets and use environment variables instead."
  fi
fi

# --- Check 5: Dependency security (if pip-audit is available) ---
if command -v pip-audit &>/dev/null; then
  AUDIT_OUTPUT=$(pip-audit --strict 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}\n❌ SECURITY: pip-audit found vulnerabilities:\n$(echo "$AUDIT_OUTPUT" | head -15)"
  fi
fi

# --- Verdict ---
if [ -n "$ERRORS" ]; then
  echo "🚫 PR GATE BLOCKED — Fix these issues before creating a PR:" >&2
  echo -e "$ERRORS" >&2
  echo "" >&2
  echo "Run each fix, then retry the PR creation." >&2
  exit 2
fi

exit 0
