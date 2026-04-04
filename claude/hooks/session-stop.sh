#!/bin/bash
# =============================================================================
# session-stop.sh — Prompt Claude to write a Session Ledger note
# =============================================================================
# Fires on Stop hook. Blocks Claude from finishing until it writes a session
# summary note to Obsidian. Guards against infinite loops via stop_hook_active.
# =============================================================================

INPUT=$(cat)

# Guard: prevent repeated blocking within the same session-hour.
# The stop_hook_active field does NOT exist in the Stop hook schema, so we
# use a temp file marker instead. Hour granularity auto-expires after ~1 hour.
MARKER="/tmp/.claude-stop-$(date +%Y%m%d-%H)"
if [[ -f "$MARKER" ]]; then
  exit 0  # Already prompted this session — allow stop
fi
touch "$MARKER"

source "$HOME/.claude/hooks/detect-org.sh"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M)
FILENAME="${DATE}-${TIME}-session.md"

cat <<EOF
{
  "decision": "block",
  "reason": "Before finishing, write a session summary note to Obsidian using mcp__obsidian__write_note. Path: 06-Sessions/$DETECTED_ORG/$FILENAME. Use this YAML frontmatter: date ($DATE), org ($DETECTED_ORG), project (infer from working directory), tags (session, $DETECTED_ORG). Include these sections: ## What was done, ## Decisions made (wikilink any ADRs created), ## Bugs fixed, ## Open threads, ## Files changed. Keep it concise. If any architectural or technical decisions were made, also create an ADR in the org Decisions/ folder using the template from 05-Templates/architecture-decision.md or 05-Templates/decision-record.md. Then you may finish."
}
EOF
