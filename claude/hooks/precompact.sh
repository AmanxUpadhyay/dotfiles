#!/bin/bash
set -euo pipefail
# =============================================================================
# precompact.sh — Block context compaction until session note is up to date
# =============================================================================
# purpose: fires on PreCompact hook; issues a decision:block telling Claude to
#   patch today's session note before its context is compacted away. Mirrors
#   session-stop.sh's delegation pattern but without the trivial-session guard
#   — compaction itself implies meaningful work happened. Uses PATCH semantics
#   (not overwrite) so the per-turn Stop writes and this pre-compact write
#   converge on one daily note rather than spawning duplicates.
# inputs: stdin JSON from PreCompact event; OBSIDIAN_VAULT + ORG_MAP from env.sh
# outputs: JSON decision=block with patch instructions; exit 0 to pass through
# side-effects: sources env.sh + detect-org.sh; no direct filesystem writes
# =============================================================================

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "PreCompact"
fi

# Consume stdin so the upstream hook harness doesn't see EPIPE; contents
# aren't needed since the decision:block doesn't parse any PreCompact fields.
cat >/dev/null 2>&1 || true

# Guard: skip in automated/cron-triggered sessions.
if [[ "${CLAUDE_AUTOMATED:-}" == "1" ]]; then
  exit 0
fi

source "$HOME/.claude/env.sh"
source "$HOME/.claude/hooks/detect-org.sh"

DATE=$(date +%Y-%m-%d)
SESSION_FOLDER=$(jq -r --arg org "$DETECTED_ORG" '.orgs[$org].session_folder // $org' "$ORG_MAP" 2>/dev/null)

cat <<EOF
{
  "decision": "block",
  "reason": "Before context compaction, patch today's session note in Obsidian so mid-session state isn't lost.\n\nPath: 06-Sessions/$SESSION_FOLDER/$DATE-<slug>.md\n\nReuse the SAME slug you've used for this session's earlier notes. If none exists yet, pick a 2-5 word kebab-case slug describing the session's main focus.\n\nIf the file exists, PATCH it — do not overwrite. Use mcp__obsidian__patch_note to append to existing sections. If MCP unavailable, Read the file, merge new content into the existing sections, then Write the merged content back.\n\nSections to maintain: ## What was done, ## Decisions made, ## Bugs fixed, ## Open threads, ## Files changed.\n\nThen you may continue."
}
EOF
