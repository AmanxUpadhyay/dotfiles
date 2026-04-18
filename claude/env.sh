#!/bin/bash
set -euo pipefail
# =============================================================================
# env.sh — Shared environment variables for Claude Code hooks and cron scripts
# =============================================================================
# purpose: centralises PATH, CLAUDE_BIN resolution, vault + log paths, and the
#   preflight_check() helper. Every hook/cron sources this first.
# inputs: none (reads $HOME; may read pre-existing CLAUDE_BIN env override).
# outputs: exports PATH, OBSIDIAN_VAULT, CLAUDE_LOG_DIR, ORG_MAP, CLAUDE_BIN.
# side-effects: none (idempotent — safe to re-source). preflight_check logs to
#   stderr when validation fails but makes no filesystem writes itself.
# =============================================================================

# Centralized PATH — applies to all consumers (cron, launchd, hooks).
# Must come first so CLAUDE_BIN resolution and child processes find all binaries.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"

# purpose: vault root for Obsidian notes written by retros and session hooks
export OBSIDIAN_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE"
# purpose: canonical log directory for all claude automation output
export CLAUDE_LOG_DIR="$HOME/Library/Logs/claude-crons"
# purpose: JSON map of org-keyword -> vault folder; used by detect-org.sh
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
# purpose: absolute path to the claude CLI binary, resolved via the chain above
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
