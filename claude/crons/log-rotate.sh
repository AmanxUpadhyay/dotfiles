#!/bin/bash
set -euo pipefail
# =============================================================================
# log-rotate.sh — Delete cron/hook logs older than 30 days
# =============================================================================
# purpose: prune ~/Library/Logs/claude-crons/*.log files older than 30d
# inputs: none
# outputs: deletion count on stdout
# side-effects: removes old .log files under $CLAUDE_LOG_DIR
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"
trap 'notify_failure log-rotate "$CLAUDE_LOG_DIR/log-rotate.log"' ERR

_START_EPOCH=$(date +%s)
LOGFILE="$CLAUDE_LOG_DIR/log-rotate.log"
mkdir -p "$CLAUDE_LOG_DIR"

# Size-based rotation of hooks-fire.log: NDJSON append-only log grows fast under
# heavy hook activity. Gzip snapshot + truncate when above threshold
# (HOOKS_FIRE_MAX_SIZE, default 10 MB). Gzipped snapshots carry a .log.gz suffix
# so the 30-day find below sweeps them too.
FIRE_LOG="$CLAUDE_LOG_DIR/hooks-fire.log"
FIRE_MAX="${HOOKS_FIRE_MAX_SIZE:-10485760}"
FIRE_ROTATED=0
if [[ -f "$FIRE_LOG" ]]; then
  FIRE_SIZE=$(stat -f%z "$FIRE_LOG" 2>/dev/null || echo 0)
  if [[ "$FIRE_SIZE" -gt "$FIRE_MAX" ]]; then
    gzip -c "$FIRE_LOG" > "$CLAUDE_LOG_DIR/hooks-fire-$(date +%Y%m%d-%H%M).log.gz"
    : > "$FIRE_LOG"
    FIRE_ROTATED=1
    echo "[$(date)] rotated hooks-fire.log (was $FIRE_SIZE bytes)" >> "$LOGFILE"
  fi
fi

COUNT=$(find "$CLAUDE_LOG_DIR" -maxdepth 1 \( -name '*.log' -o -name '*.log.gz' \) -mtime +30 -delete -print | wc -l | tr -d ' ')
echo "[$(date)] rotated $COUNT files (fire_rotated=$FIRE_ROTATED)" >> "$LOGFILE"

_DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
echo "duration_ms=$_DURATION_MS status=ok" >> "$LOGFILE"
touch "$CLAUDE_LOG_DIR/.last-success-log-rotate"
