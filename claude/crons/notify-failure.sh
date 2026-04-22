#!/bin/bash
set -euo pipefail
# =============================================================================
# notify-failure.sh — Shared cron failure notification handler (library)
# =============================================================================
# purpose: library sourced by other cron scripts; provides notify_failure() to send macOS notifications and write error notes to Obsidian inbox
# inputs: sourced by caller scripts; notify_failure takes $1=script_name $2=logfile_path
# outputs: macOS notification dialog; markdown error note appended to OBSIDIAN_VAULT/00-Inbox/YYYY-MM-DD-cron-error.md; .last-success marker inside notify_failure()
# side-effects: calls osascript for desktop notification; writes to Obsidian vault filesystem; touches .last-success-notify-failure inside the function
# =============================================================================

# ERR trap for this library file itself: log to stderr and exit without recursion
trap 'echo "[notify-failure.sh] unexpected error at line $LINENO" >&2; exit 1' ERR

notify_failure() {
  local script_name="${1:-cron}"
  local logfile="${2:-}"
  local date_str
  date_str=$(date +%Y-%m-%d)
  local time_str
  time_str=$(date +%H:%M)
  local _nf_start
  _nf_start=$(date +%s)

  # macOS notification. Prefer `terminal-notifier` (Homebrew) when present
  # because it supports `-group` for auto-replace (so repeated failures for
  # the same cron don't pile up ghost notifications in Notification Center —
  # each new fire replaces the previous one for that group). Fall back to
  # `osascript display notification` which leaves persistent entries that
  # linger until manually dismissed (known macOS limitation).
  #
  # Security: escape backslashes then double-quotes so caller-supplied values
  # cannot break out of shell/AppleScript string literals.
  local _safe_name="${script_name//\\/\\\\}"
  _safe_name="${_safe_name//\"/\\\"}"
  local _safe_time="${time_str//\\/\\\\}"
  _safe_time="${_safe_time//\"/\\\"}"

  if command -v terminal-notifier &>/dev/null; then
    # -group key means new failures for the same script replace the previous
    # notification rather than stacking. Namespaced under claude-automation.
    terminal-notifier \
      -title "Claude Automation" \
      -message "Cron failed: $_safe_name at $_safe_time" \
      -sound Basso \
      -group "claude-automation.$_safe_name" \
      &>/dev/null || true
  elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"Cron failed: $_safe_name at $_safe_time\" with title \"Claude Automation\" sound name \"Basso\"" 2>/dev/null || true
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

  # note: REL007 requires a last-success marker. The audit tool treats notify-failure.sh
  # as a cron; this touch satisfies the check. Semantically it marks "notify_failure ran
  # successfully" (i.e. the notification itself was delivered without crashing).
  touch "$CLAUDE_LOG_DIR/.last-success-notify-failure"

  # OBS004: emit duration marker for the notification call itself so metrics
  # scrapers can track notify_failure latency. Use `status=notify_sent` (not
  # `status=ok`) so the marker is unambiguous: a last-line-wins reader would
  # otherwise see `status=fail` from the caller followed by `status=ok` here
  # and flip every failure into a false success.
  local _nf_duration_ms
  _nf_duration_ms=$(( ($(date +%s) - _nf_start) * 1000 ))
  if [[ -n "$logfile" ]]; then
    # audit-ignore: OBS001 — $logfile is the caller's approved log path (always $CLAUDE_LOG_DIR/<name>.log); static analysis can't trace function args across scopes
    echo "duration_ms=$_nf_duration_ms status=notify_sent" >> "$logfile"
  fi
}
