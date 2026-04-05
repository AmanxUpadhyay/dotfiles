#!/bin/bash
# =============================================================================
# claude-mem-worker.sh — Stable entrypoint for claude-mem worker service
# =============================================================================
# The LaunchAgent points here instead of directly into the plugin cache.
# This wrapper resolves the active worker script at launch time, so the
# plist doesn't need updating when the claude-mem plugin version changes.
#
# Priority:
#   1. Installed (active) version at marketplaces/thedotmack/plugin/
#   2. Latest cached version (sorted by semver directory name)
# =============================================================================

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

exec "$BUN" "$WORKER"
