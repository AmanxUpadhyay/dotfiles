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

COUNT=$(find "$CLAUDE_LOG_DIR" -maxdepth 1 -name '*.log' -mtime +30 -delete -print | wc -l | tr -d ' ')
echo "[$(date)] rotated $COUNT files" >> "$LOGFILE"

_DURATION_MS=$(( ($(date +%s) - _START_EPOCH) * 1000 ))
echo "duration_ms=$_DURATION_MS status=ok" >> "$LOGFILE"
touch "$CLAUDE_LOG_DIR/.last-success-log-rotate"
