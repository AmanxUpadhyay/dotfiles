#!/bin/bash
# =============================================================================
# session-stop.sh — Prompt Claude to write a Session Ledger note
# =============================================================================
# Fires on Stop hook. Blocks Claude from finishing until it writes a session
# summary note to Obsidian.
#
# Loop prevention: uses stop_hook_active from official Stop hook input schema
# (docs.anthropic.com/en/docs/claude-code/hooks) instead of marker files.
# =============================================================================

INPUT=$(cat)

# Guard: skip session notes in automated/cron-triggered sessions.
if [[ "$CLAUDE_AUTOMATED" == "1" ]]; then
  exit 0
fi

# Guard: already continuing from a stop hook — prevent infinite loop.
# stop_hook_active is the official loop-prevention field in Stop hook input.
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
  exit 0
fi

source "$HOME/.claude/env.sh"
source "$HOME/.claude/hooks/detect-org.sh"

DATE=$(date +%Y-%m-%d)
SESSION_FOLDER="$OBSIDIAN_VAULT/06-Sessions/$DETECTED_ORG"

cat <<EOF
{
  "decision": "block",
  "reason": "Before finishing, write a session summary note to Obsidian. Choose a descriptive 2-5 word slug (hyphenated, lowercase) summarising this session (e.g. vault-config, hook-audit-plan, auth-refactor). Path: 06-Sessions/$DETECTED_ORG/$DATE-<your-slug>.md. Use this YAML frontmatter: date ($DATE), org ($DETECTED_ORG), project (infer from working directory), tags (session, $DETECTED_ORG). The note body must begin with: Part of $DETECTED_WIKILINK. Then include these sections: ## What was done, ## Decisions made (wikilink any ADRs created), ## Bugs fixed, ## Open threads, ## Files changed. Keep it concise. Try mcp__obsidian__write_note first. If MCP is unavailable, write directly to $SESSION_FOLDER/$DATE-<your-slug>.md using the Write tool. If any architectural or technical decisions were made, also create an ADR in the org Decisions/ folder using the template from 05-Templates/architecture-decision.md or 05-Templates/decision-record.md. Then you may finish."
}
EOF
