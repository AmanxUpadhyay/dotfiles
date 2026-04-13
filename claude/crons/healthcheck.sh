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

# Log rotation: keep healthcheck.log from growing unbounded
if [[ -f "$LOGFILE" ]] && (( $(stat -f %z "$LOGFILE" 2>/dev/null || echo 0) > 102400 )); then
  mv "$LOGFILE" "${LOGFILE}.1"
fi

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
    # Audit log: record which binary and version will be used by crons today
    _claude_version=$("$CLAUDE_BIN" --version 2>/dev/null | head -1)
    echo "  CLAUDE_BIN: $CLAUDE_BIN ($_claude_version)" >> "$LOGFILE"
    unset _claude_version
  fi

  # npx availability (required for Obsidian MCP server: npx @bitbonsai/mcpvault)
  if ! command -v npx &>/dev/null; then
    errors+=("npx not found in PATH — Obsidian MCP server cannot start")
  fi

  # Claude Desktop must be running for scheduled tasks
  if ! pgrep -x "Claude" >/dev/null; then
    errors+=("Claude Desktop not running — scheduled tasks won't fire")
  fi

  # Vault + config
  [[ ! -d "$OBSIDIAN_VAULT" ]] && errors+=("OBSIDIAN_VAULT not accessible: $OBSIDIAN_VAULT")
  [[ ! -f "$ORG_MAP" ]]        && errors+=("ORG_MAP not found: $ORG_MAP")

  # Validate org-map JSON
  if [[ -f "$ORG_MAP" ]] && ! python3 -m json.tool "$ORG_MAP" &>/dev/null; then
    errors+=("ORG_MAP is not valid JSON: $ORG_MAP")
  fi

  # Prompt templates
  for tmpl in daily-retrospective daily-retro-evening weekly-report-gen weekly-finalize; do
    [[ ! -f "$PROMPTS_DIR/$tmpl.md" ]] && errors+=("Prompt template missing: $PROMPTS_DIR/$tmpl.md")
  done

  # Log dir writable
  if ! touch "$CLAUDE_LOG_DIR/.healthcheck-write-test" 2>/dev/null; then
    errors+=("CLAUDE_LOG_DIR not writable: $CLAUDE_LOG_DIR")
  else
    rm -f "$CLAUDE_LOG_DIR/.healthcheck-write-test"
  fi

  # Vault structure: critical directories that cron scripts write to
  local vault_dirs=(
    "01-LXS/Decisions"
    "01-LXS/reports/weekly"
    "02-Startups/AdTecher/Decisions"
    "02-Startups/AdTecher/reports/weekly"
    "02-Startups/Ledgx/reports/weekly"
    "03-Clients/ClubRevAI/reports/weekly"
    "03-Clients/Wayv Telcom/reports/weekly"
    "06-Sessions/Personal"
    "06-Sessions/LXS"
    "07-Daily"
  )
  for vdir in "${vault_dirs[@]}"; do
    [[ ! -d "$OBSIDIAN_VAULT/$vdir" ]] && errors+=("Vault dir missing: $vdir")
  done

  FAILURES+=("${errors[@]}")
}

# ---------------------------------------------------------------------------
# Phase 2: Post-run — verify that recent crons produced notes in the vault
# ---------------------------------------------------------------------------
run_postrun() {
  local errors=()
  local dow
  dow=$(date +%u)  # 1=Mon … 7=Sun

  # Daily note check: morning task (09:00) creates YESTERDAY's note
  # By 11:00, yesterday's note should exist in the vault
  local YESTERDAY
  YESTERDAY=$(date -v-1d +%Y-%m-%d)
  if ! ls "$OBSIDIAN_VAULT/07-Daily/$YESTERDAY"*.md &>/dev/null; then
    errors+=("Daily note for $YESTERDAY not found in vault")
  fi

  # Weekly note check: on Sat/Sun/Mon, last week's summary should exist
  if [[ "$dow" =~ ^(6|7|1)$ ]]; then
    # Get last week's number
    local LAST_WEEK
    LAST_WEEK=$(date -v-7d +%Y-W%V)
    if ! ls "$OBSIDIAN_VAULT/07-Daily/$LAST_WEEK"*.md &>/dev/null; then
      errors+=("Weekly summary for $LAST_WEEK not found in vault")
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
