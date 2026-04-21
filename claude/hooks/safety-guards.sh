#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PreToolUse"
fi
# =============================================================================
# safety-guards.sh — Block Dangerous Bash Commands
# =============================================================================
# purpose: pattern-matches every Bash command Claude runs before execution and hard-blocks destructive operations via exit 2
# inputs: stdin JSON with tool_input.command from PreToolUse event; operates on Bash commands only
# outputs: exit 2 with stderr explanation if blocked; exit 0 to allow; stderr is returned to Claude as feedback
# side-effects: none; uses bash builtins for performance (zero subprocesses per check)
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
# Critical targets: / ~/  ~ (root only), $HOME, .., /usr, /etc, /var, /opt, /bin, /sbin, /lib, *, ./
if [[ "$COMMAND" =~ (sudo[[:space:]]+)?rm[[:space:]]+(-[rRfF]+[[:space:]]+)+(\/[[:space:]]|\/+$|~\/+$|~/[[:space:]]|~[[:space:]]|~$|[.][.]|/usr(/|[[:space:]]|$)|/etc(/|[[:space:]]|$)|/var(/|[[:space:]]|$)|/opt(/|[[:space:]]|$)|/bin(/|[[:space:]]|$)|/sbin(/|[[:space:]]|$)|/lib(/|[[:space:]]|$)|\*|[.]/[[:space:]]|\"[.]\"|[.][[:space:]]|\$HOME) ]]; then
  echo "BLOCKED: Recursive deletion targeting critical directory or wildcard. Use a specific path instead." >&2
  exit 2
fi

# Case-insensitive catch for system path targets (macOS filesystem is case-insensitive)
if [[ "$COMMAND_LOWER" =~ rm[[:space:]]+(-[rrff]+[[:space:]]+)+(/usr(/|[[:space:]]|$)|/etc(/|[[:space:]]|$)|/var(/|[[:space:]]|$)|/opt(/|[[:space:]]|$)|/bin(/|[[:space:]]|$)|/sbin(/|[[:space:]]|$)|/lib(/|[[:space:]]|$)) ]]; then
  echo "BLOCKED: Recursive deletion targeting critical system directory. Use a specific path instead." >&2
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
