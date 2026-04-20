#!/bin/bash
set -euo pipefail
# =============================================================================
# session-stop.sh — Block Claude to Write Session Ledger Note
# =============================================================================
# purpose: fires on Stop hook and blocks Claude from finishing until it writes a session summary note to Obsidian; keeps Claude in-session so MCP tools remain authenticated
# inputs: stdin JSON with stop_hook_active, transcript_path from Stop event; OBSIDIAN_VAULT, ORG_MAP from env.sh; sources detect-org.sh
# outputs: JSON decision=block with instructions for writing the session note; exit 0 to pass through
# side-effects: reads transcript file to count edits; skips for trivial sessions (<1 edit) and automated sessions; skips if stop_hook_active=true to prevent infinite loop
# =============================================================================

INPUT=$(cat)

# Guard: skip in automated/cron-triggered sessions.
if [[ "$CLAUDE_AUTOMATED" == "1" ]]; then
  exit 0
fi

# Guard: already continuing from a stop hook — prevent infinite loop.
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
  exit 0
fi

# Guard: skip for trivial sessions (quick Q&A with no real work).
# Check if session had meaningful tool usage via transcript.
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  # Count edit/write tools (indicates real work)
  EDIT_COUNT=$(jq -s '[.[] | .message.content[]? | select(.type == "tool_use") | select(.name | test("Write|Edit|MultiEdit|mcp__obsidian__write"))] | length' "$TRANSCRIPT" 2>/dev/null || echo 0)

  # Skip if no edits/writes were made
  if [[ "$EDIT_COUNT" -lt 1 ]]; then
    exit 0
  fi
fi

source "$HOME/.claude/env.sh"
source "$HOME/.claude/hooks/detect-org.sh"

DATE=$(date +%Y-%m-%d)
SESSION_FOLDER=$(jq -r --arg org "$DETECTED_ORG" '.orgs[$org].session_folder // $org' "$ORG_MAP" 2>/dev/null)
VAULT_SESSION_PATH="$OBSIDIAN_VAULT/06-Sessions/$SESSION_FOLDER"

cat <<EOF
{
  "decision": "block",
  "reason": "Before finishing, write a session summary note to Obsidian.\n\nPath: 06-Sessions/$SESSION_FOLDER/$DATE-<slug>.md (choose a descriptive 2-5 word kebab-case slug like 'hook-oauth-fix' or 'auth-refactor').\n\nFrontmatter: date: $DATE, org: $DETECTED_ORG, type: session, tags: [session, $(echo "$DETECTED_ORG" | tr '[:upper:]' '[:lower:]')]\n\nBody starts with: Part of $DETECTED_WIKILINK\n\nSections:\n## What was done (3-5 bullets, be specific)\n## Decisions made (or 'None')\n## Bugs fixed (or 'None')\n## Open threads (or 'None')\n## Files changed\n\nUse mcp__obsidian__write_note. If MCP unavailable, use Write tool to $VAULT_SESSION_PATH/$DATE-<slug>.md.\n\nIf bugs were fixed, also create Bug-Jar entries at 04-Knowledge/Bug-Jar/$DATE-<bug-slug>.md.\n\nThen you may finish."
}
EOF
