#!/bin/bash
# =============================================================================
# GODL1KE safety-guards.sh — Block Dangerous Bash Commands
# =============================================================================
# WHY: This hook fires BEFORE every Bash command Claude runs. It pattern-
# matches against known destructive operations and blocks them with exit 2.
# Exit 2 = hard block. Stderr is sent back to Claude as feedback.
# Exit 0 = allow. Exit 1 = warning only (DOES NOT BLOCK — never use for safety).
#
# Performance: uses bash [[ =~ ]] builtins instead of echo | grep forks.
# Each Bash command invocation previously spawned ~20 subprocesses; now 0.
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

# Lowercase copy for case-insensitive checks (bash 3 compatible)
COMMAND_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

# --- Destructive file operations ---
# Match: rm -rf, rm -fr, rm -r -f, sudo rm -rf, with critical targets
# Critical targets: /, ~, $HOME, .., /usr, /etc, /var, /opt, /bin, /sbin, /lib, *, ./  .
if [[ "$COMMAND" =~ (sudo[[:space:]]+)?rm[[:space:]]+(-[rRfF]+[[:space:]]+)+(/|~|[.][.]|/usr|/etc|/var|/opt|/bin|/sbin|/lib|\*|[.]/[[:space:]]|\"[.]\"|[.][[:space:]]|\"[.]\"|\$HOME) ]]; then
  echo "BLOCKED: Recursive deletion targeting critical directory or wildcard. Use a specific path instead." >&2
  exit 2
fi

# Catch rm -rf * and rm -fr * (wildcard without path prefix)
if [[ "$COMMAND" =~ rm[[:space:]]+-[rRfFrF]*[[:space:]].*\* ]]; then
  echo "BLOCKED: Recursive deletion with wildcard target. Use a specific path instead." >&2
  exit 2
fi

# --- Git: force push ---
if [[ "$COMMAND" =~ git[[:space:]]+push[[:space:]].*(-f|--force)[^-] ]]; then
  if [[ ! "$COMMAND" =~ force-with-lease ]]; then
    echo "BLOCKED: Force push prohibited. Use --force-with-lease for safer force pushes." >&2
    exit 2
  fi
fi

# --- Git: direct push to main/master ---
if [[ "$COMMAND" =~ git[[:space:]]+push[[:space:]]+(origin[[:space:]]+)?(main|master)([[:space:]]|$) ]]; then
  echo "BLOCKED: Direct push to main/master prohibited. Create a feature branch and open a PR." >&2
  exit 2
fi

# --- Git: hard reset ---
if [[ "$COMMAND" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
  echo "BLOCKED: git reset --hard destroys uncommitted work. Use git stash instead." >&2
  exit 2
fi

# --- Destructive SQL ---
if [[ "$COMMAND_LOWER" =~ (drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table|delete[[:space:]]+from[[:space:]]+[^[:space:]]+[[:space:]]*;) ]]; then
  echo "BLOCKED: Destructive SQL operation detected. Use a migration or a safer approach." >&2
  exit 2
fi

# --- Production database connections ---
if [[ "$COMMAND_LOWER" =~ (psql|mysql|mongo|redis-cli).*prod(uction)? ]]; then
  echo "BLOCKED: Direct production database access prohibited. Use a read-only replica or staging." >&2
  exit 2
fi

# --- Alembic downgrade in production ---
if [[ "$COMMAND_LOWER" =~ alembic[[:space:]]+downgrade.*prod ]]; then
  echo "BLOCKED: Alembic downgrade against production prohibited. Test migrations in staging first." >&2
  exit 2
fi

# --- Pipe to shell (curl | bash) ---
if [[ "$COMMAND" =~ curl.*\|[[:space:]]*(bash|sh|zsh) ]]; then
  echo "BLOCKED: Piping remote content to shell is dangerous. Download first, review, then execute." >&2
  exit 2
fi

# --- Fork bombs ---
if [[ "$COMMAND" =~ :\(\)\{.*\|.*\} ]]; then
  echo "BLOCKED: Fork bomb detected." >&2
  exit 2
fi

# --- chmod 777 ---
if [[ "$COMMAND" =~ chmod[[:space:]]+777 ]]; then
  echo "BLOCKED: chmod 777 is a security risk. Use specific permissions (e.g., 755 for dirs, 644 for files)." >&2
  exit 2
fi

exit 0
