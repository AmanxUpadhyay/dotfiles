#!/bin/bash
# =============================================================================
# env.sh — Shared environment variables for Claude Code hooks and cron scripts
# =============================================================================
# Source this file from any hook or cron script that needs these variables.
# Symlinked at ~/.claude/env.sh -> ~/.dotfiles/claude/env.sh
# =============================================================================

# Centralized PATH — applies to all consumers (cron, launchd, hooks).
# Must come first so CLAUDE_BIN resolution and child processes find all binaries.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"

export OBSIDIAN_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE"
export CLAUDE_LOG_DIR="$HOME/Library/Logs/claude-crons"
export ORG_MAP="$HOME/.claude/org-map.json"

# Resolve CLAUDE_BIN: respect env override, fall back to known install paths in priority order
if [[ -z "${CLAUDE_BIN:-}" ]] || [[ ! -x "${CLAUDE_BIN:-}" ]]; then
  for _candidate in \
    "$HOME/.local/bin/claude" \
    "$HOME/.npm-packages/bin/claude" \
    "/opt/homebrew/bin/claude"; do
    if [[ -x "$_candidate" ]]; then
      CLAUDE_BIN="$_candidate"
      break
    fi
  done
  unset _candidate
fi
export CLAUDE_BIN

# Validate critical environment variables before any cron script proceeds.
# Call this after sourcing notify-failure.sh so notify_failure is available.
preflight_check() {
  local caller="${1:-unknown}"
  local errors=()

  [[ ! -x "${CLAUDE_BIN:-}" ]] && errors+=("CLAUDE_BIN not found or not executable: ${CLAUDE_BIN:-<unset>}")
  [[ ! -d "$OBSIDIAN_VAULT" ]]  && errors+=("OBSIDIAN_VAULT not accessible: $OBSIDIAN_VAULT")
  [[ ! -f "$ORG_MAP" ]]         && errors+=("ORG_MAP not found: $ORG_MAP")

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "[$(date)] PREFLIGHT FAILED for $caller:" >&2
    printf '  - %s\n' "${errors[@]}" >&2
    return 1
  fi
  return 0
}
