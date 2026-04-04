#!/bin/bash
# =============================================================================
# breadcrumb-writer.sh — Write session breadcrumb to project repo
# =============================================================================
# SessionEnd hook (async). Writes a lightweight .claude/breadcrumbs.md into
# the project repo so the next session can find the relevant vault notes.
# =============================================================================

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

# Guard: only write breadcrumbs inside a git repo
if ! git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

source "$HOME/.claude/hooks/detect-org.sh"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)
BRANCH=$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")

BREADCRUMB_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude"
mkdir -p "$BREADCRUMB_DIR" 2>/dev/null

cat > "$BREADCRUMB_DIR/breadcrumbs.md" <<EOF
## Latest session: $DATE $TIME
- Organisation: $DETECTED_ORG
- Branch: $BRANCH
- Session ID: $SESSION_ID
- Vault session notes: 06-Sessions/$DETECTED_ORG/
- Decisions: vault org Decisions/ folder
- Bug fixes: 04-Knowledge/Bug-Jar/
EOF

exit 0
