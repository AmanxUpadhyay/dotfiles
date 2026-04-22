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
# Prepend our known-good paths but keep any pre-existing PATH at the FRONT
# so callers (e.g. bats tests) can stub binaries via $BATS_TEST_TMPDIR/bin.
# Without this, env.sh's PATH reset would bypass test stubs of osascript /
# pgrep / npx and leak real macOS notifications from notify-failure during
# tests that intentionally trigger preflight failures.
export PATH="${PATH:+$PATH:}$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"

# purpose: vault root for Obsidian notes written by retros and session hooks.
# Respect a pre-existing override so tests can point at a tmpdir.
export OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE}"
# purpose: canonical log directory for all claude automation output
export CLAUDE_LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/Library/Logs/claude-crons}"
# purpose: JSON map of org-keyword -> vault folder; used by detect-org.sh
export ORG_MAP="${ORG_MAP:-$HOME/.claude/org-map.json}"

# purpose: HTTP port for the claude-mem worker (bun HTTP server).
# The plugin ships an upstream formula `37700 + (uid % 100)` in its
# UserPromptSubmit hook (~/.claude/plugins/cache/thedotmack/claude-mem/<v>/
# hooks/hooks.json). The worker's own default is a hardcoded 37777 —
# mismatch means the plugin's per-prompt hook can't reach the worker and
# fails with exit 1, surfacing in Claude Code as "Hook Error Failed with
# non-blocking status code: No stderr output" on every UserPromptSubmit.
# Fix: align both sides on the plugin's formula. When the
# claude-mem-worker launchd script sources this file, it picks up
# CLAUDE_MEM_WORKER_PORT and bun binds to the matching port. Our
# session-start.sh injection reads the same var.
export CLAUDE_MEM_WORKER_PORT="${CLAUDE_MEM_WORKER_PORT:-$((37700 + $(id -u 2>/dev/null || echo 77) % 100))}"

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

# Run "$@" with a timeout using pure-bash. Returns the command's exit code,
# or a nonzero code if it timed out. No external dependencies — avoids GNU
# `timeout` (coreutils) which is not shipped on macOS.
# Usage: bash_timeout <seconds> <command> [args...]
bash_timeout() {
  local limit="$1"; shift
  "$@" &
  local _bt_pid=$!
  ( sleep "$limit" && kill -9 "$_bt_pid" 2>/dev/null ) &
  local _bt_watchdog=$!
  local _bt_rc=0
  # Use || to capture exit code safely under set -e (if ! ... loses the code)
  wait "$_bt_pid" 2>/dev/null || _bt_rc=$?
  kill "$_bt_watchdog" 2>/dev/null || true
  wait "$_bt_watchdog" 2>/dev/null || true
  return $_bt_rc
}

# Validate critical environment variables before any cron script proceeds.
# Call this after sourcing notify-failure.sh so notify_failure is available.
preflight_check() {
  local caller="${1:-unknown}"
  local errors=()

  [[ ! -x "${CLAUDE_BIN:-}" ]] && errors+=("CLAUDE_BIN not found or not executable: ${CLAUDE_BIN:-<unset>}")
  [[ ! -d "$OBSIDIAN_VAULT" ]]  && errors+=("OBSIDIAN_VAULT not accessible: $OBSIDIAN_VAULT")
  [[ ! -f "$ORG_MAP" ]]         && errors+=("ORG_MAP not found: $ORG_MAP")

  # Verify binary responds within a short timeout (catches hung/broken installs).
  # Uses the shared bash_timeout helper — no GNU coreutils dependency.
  if [[ -x "${CLAUDE_BIN:-}" ]]; then
    if ! bash_timeout 10 "$CLAUDE_BIN" --version &>/dev/null; then
      errors+=("CLAUDE_BIN did not respond to --version within 10s: $CLAUDE_BIN")
    fi
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "[$(date)] PREFLIGHT FAILED for $caller:" >&2
    printf '  - %s\n' "${errors[@]}" >&2
    return 1
  fi
  return 0
}
