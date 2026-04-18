#!/bin/bash
set -euo pipefail
# =============================================================================
# claude-mem-worker.sh — Stable entrypoint for claude-mem worker service
# =============================================================================
# purpose: resolve and launch the active claude-mem worker-service.cjs via bun
# inputs: none (reads CLAUDE_LOG_DIR from env.sh; plugin paths are hardcoded)
# outputs: none (exec replaces the process; success marker written on clean exit)
# side-effects: starts long-running bun process; touches .last-success-claude-mem-worker on success
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure claude-mem-worker "$LOGFILE"' ERR

LOGFILE="$CLAUDE_LOG_DIR/claude-mem-worker-$(date +%Y-%m-%d).log"
mkdir -p "$CLAUDE_LOG_DIR"

BUN="/opt/homebrew/bin/bun"
PLUGIN_BASE="$HOME/.claude/plugins"

# 1. Prefer the actively installed version
WORKER="$PLUGIN_BASE/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"

# 2. Fall back to highest cached version
if [[ ! -f "$WORKER" ]]; then
  WORKER=$(ls "$PLUGIN_BASE/cache/thedotmack/claude-mem/"*/scripts/worker-service.cjs 2>/dev/null | sort -V | tail -1)
fi

if [[ -z "$WORKER" || ! -f "$WORKER" ]]; then
  echo "[$(date)] ERROR: claude-mem worker-service.cjs not found" >&2
  exit 1
fi

touch "$CLAUDE_LOG_DIR/.last-success-claude-mem-worker"

exec "$BUN" "$WORKER"
