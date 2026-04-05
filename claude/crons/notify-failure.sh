#!/bin/bash
# =============================================================================
# notify-failure.sh — Shared cron failure notification handler
# =============================================================================
# Source this in cron scripts, then call: notify_failure "$SCRIPT_NAME" "$LOG"
# Sends macOS notification + writes error note to Obsidian inbox.
# =============================================================================

notify_failure() {
  local script_name="${1:-cron}"
  local logfile="${2:-}"
  local date_str
  date_str=$(date +%Y-%m-%d)
  local time_str
  time_str=$(date +%H:%M)

  # macOS notification (silent if osascript unavailable)
  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"Cron failed: $script_name at $time_str\" with title \"Claude Automation\" sound name \"Basso\"" 2>/dev/null || true
  fi

  # Write error note to Obsidian inbox (direct filesystem write — no MCP dependency)
  local note_path="$OBSIDIAN_VAULT/00-Inbox/${date_str}-cron-error.md"
  cat >> "$note_path" <<EOF
## ❌ Cron failure: $script_name

- **Time**: $date_str $time_str
- **Script**: $script_name
- **Log**: $logfile

$(if [[ -n "$logfile" && -f "$logfile" ]]; then tail -20 "$logfile"; fi)

---
EOF
}
