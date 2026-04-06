#!/bin/bash
# =============================================================================
# healthcheck.sh — Validate cron environment + verify recent run markers
# =============================================================================
# Usage:
#   healthcheck.sh preflight   — validate env/binary/files (run at 08:50)
#   healthcheck.sh postrun     — check run markers for freshness (run at 11:00)
#   healthcheck.sh             — run both phases
# =============================================================================

source "$HOME/.claude/env.sh"
source "$HOME/.dotfiles/claude/crons/notify-failure.sh"

MODE="${1:-both}"
LOGFILE="$CLAUDE_LOG_DIR/healthcheck.log"
mkdir -p "$CLAUDE_LOG_DIR"

PROMPTS_DIR="$HOME/.dotfiles/claude/prompts"
MARKER_DIR="$CLAUDE_LOG_DIR"

FAILURES=()

# ---------------------------------------------------------------------------
# Phase 1: Pre-flight — validate environment before crons run
# ---------------------------------------------------------------------------
run_preflight() {
  local errors=()

  # Binary check
  if [[ ! -x "${CLAUDE_BIN:-}" ]]; then
    errors+=("CLAUDE_BIN not executable: ${CLAUDE_BIN:-<unset>}")
  else
    "$CLAUDE_BIN" --version &>/dev/null || errors+=("CLAUDE_BIN --version failed: $CLAUDE_BIN")
  fi

  # Vault + config
  [[ ! -d "$OBSIDIAN_VAULT" ]] && errors+=("OBSIDIAN_VAULT not accessible: $OBSIDIAN_VAULT")
  [[ ! -f "$ORG_MAP" ]]        && errors+=("ORG_MAP not found: $ORG_MAP")

  # Validate org-map JSON
  if [[ -f "$ORG_MAP" ]] && ! python3 -m json.tool "$ORG_MAP" &>/dev/null; then
    errors+=("ORG_MAP is not valid JSON: $ORG_MAP")
  fi

  # Prompt templates
  for tmpl in daily-retrospective weekly-report-gen weekly-finalize; do
    [[ ! -f "$PROMPTS_DIR/$tmpl.md" ]] && errors+=("Prompt template missing: $PROMPTS_DIR/$tmpl.md")
  done

  # Log dir writable
  if ! touch "$CLAUDE_LOG_DIR/.healthcheck-write-test" 2>/dev/null; then
    errors+=("CLAUDE_LOG_DIR not writable: $CLAUDE_LOG_DIR")
  else
    rm -f "$CLAUDE_LOG_DIR/.healthcheck-write-test"
  fi

  FAILURES+=("${errors[@]}")
}

# ---------------------------------------------------------------------------
# Phase 2: Post-run — verify that recent crons touched their markers
# ---------------------------------------------------------------------------
run_postrun() {
  local errors=()
  local now
  now=$(date +%s)
  local dow
  dow=$(date +%u)  # 1=Mon … 7=Sun

  # Daily: marker must be < 2h15m old (cron fired at 08:57, checked at 11:00)
  local daily_marker="$MARKER_DIR/.last-success-daily-retrospective"
  if [[ ! -f "$daily_marker" ]]; then
    errors+=("daily-retrospective has never succeeded (no marker file)")
  else
    local age=$(( now - $(stat -f %m "$daily_marker") ))
    if (( age > 8100 )); then  # 2h15m = 8100 seconds
      errors+=("daily-retrospective marker is stale ($(( age / 60 ))m old, expected < 135m)")
    fi
  fi

  # Weekly report-gen: fires Friday 17:02. Check on Sat (dow=6), Sun (7), Mon (1)
  if [[ "$dow" =~ ^(6|7|1)$ ]]; then
    local gen_marker="$MARKER_DIR/.last-success-weekly-report-gen"
    if [[ ! -f "$gen_marker" ]]; then
      errors+=("weekly-report-gen has never succeeded (no marker file)")
    else
      local age=$(( now - $(stat -f %m "$gen_marker") ))
      if (( age > 259200 )); then  # 3 days = 259200 seconds
        errors+=("weekly-report-gen marker is stale ($(( age / 3600 ))h old, expected < 72h)")
      fi
    fi
  fi

  # Weekly finalize: fires Monday 09:03. Check on Tue (dow=2), Wed (3), Thu (4)
  if [[ "$dow" =~ ^(2|3|4)$ ]]; then
    local fin_marker="$MARKER_DIR/.last-success-weekly-finalize"
    if [[ ! -f "$fin_marker" ]]; then
      errors+=("weekly-finalize has never succeeded (no marker file)")
    else
      local age=$(( now - $(stat -f %m "$fin_marker") ))
      if (( age > 259200 )); then  # 3 days = 259200 seconds
        errors+=("weekly-finalize marker is stale ($(( age / 3600 ))h old, expected < 72h)")
      fi
    fi
  fi

  FAILURES+=("${errors[@]}")
}

# ---------------------------------------------------------------------------
# Run requested phase(s)
# ---------------------------------------------------------------------------
[[ "$MODE" == "preflight" || "$MODE" == "both" ]] && run_preflight
[[ "$MODE" == "postrun"   || "$MODE" == "both" ]] && run_postrun

# ---------------------------------------------------------------------------
# Report results
# ---------------------------------------------------------------------------
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "[$(date)] HEALTHCHECK FAILED ($MODE): ${#FAILURES[@]} issue(s)" >> "$LOGFILE"
  printf '  - %s\n' "${FAILURES[@]}" >> "$LOGFILE"
  notify_failure "healthcheck-$MODE" "$LOGFILE"
  exit 1
else
  echo "[$(date)] HEALTHCHECK OK ($MODE)" >> "$LOGFILE"
  exit 0
fi
