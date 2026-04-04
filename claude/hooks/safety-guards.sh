#!/bin/bash
# =============================================================================
# GODL1KE safety-guards.sh — Block Dangerous Bash Commands
# =============================================================================
# WHY: This hook fires BEFORE every Bash command Claude runs. It pattern-
# matches against known destructive operations and blocks them with exit 2.
# Exit 2 = hard block. Stderr is sent back to Claude as feedback.
# Exit 0 = allow. Exit 1 = warning only (DOES NOT BLOCK — never use for safety).
#
# Location: ~/.claude/hooks/safety-guards.sh
# Triggered by: PreToolUse → Bash
# =============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Guard: empty command
if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Destructive file operations ---
if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+(/|~|\$HOME|\.\.|/usr|/etc|/var)'; then
  echo "BLOCKED: Recursive deletion targeting critical directory. Use a specific path instead." >&2
  exit 2
fi

# --- Git: force push ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(-f|--force)\b'; then
  if ! echo "$COMMAND" | grep -q 'force-with-lease'; then
    echo "BLOCKED: Force push prohibited. Use --force-with-lease for safer force pushes." >&2
    exit 2
  fi
fi

# --- Git: direct push to main/master ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+(origin\s+)?(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master prohibited. Create a feature branch and open a PR." >&2
  exit 2
fi

# --- Git: hard reset ---
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard destroys uncommitted work. Use git stash instead." >&2
  exit 2
fi

# --- Destructive SQL ---
if echo "$COMMAND" | grep -qiE '(DROP\s+(TABLE|DATABASE|SCHEMA)|TRUNCATE\s+TABLE|DELETE\s+FROM\s+\S+\s*;)'; then
  echo "BLOCKED: Destructive SQL operation detected. Use a migration or a safer approach." >&2
  exit 2
fi

# --- Production database connections ---
if echo "$COMMAND" | grep -qiE '(psql|mysql|mongo|redis-cli).*prod(uction)?'; then
  echo "BLOCKED: Direct production database access prohibited. Use a read-only replica or staging." >&2
  exit 2
fi

# --- Alembic downgrade in production ---
if echo "$COMMAND" | grep -qiE 'alembic\s+downgrade.*prod'; then
  echo "BLOCKED: Alembic downgrade against production prohibited. Test migrations in staging first." >&2
  exit 2
fi

# --- Pipe to shell (curl | bash) ---
if echo "$COMMAND" | grep -qE 'curl.*\|\s*(bash|sh|zsh)'; then
  echo "BLOCKED: Piping remote content to shell is dangerous. Download first, review, then execute." >&2
  exit 2
fi

# --- Fork bombs ---
if echo "$COMMAND" | grep -qE ':\(\)\{.*\|.*\}'; then
  echo "BLOCKED: Fork bomb detected." >&2
  exit 2
fi

# --- chmod 777 ---
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
  echo "BLOCKED: chmod 777 is a security risk. Use specific permissions (e.g., 755 for dirs, 644 for files)." >&2
  exit 2
fi

exit 0
