#!/bin/bash
set -euo pipefail
# =============================================================================
# breadcrumb-writer.sh — Write session breadcrumb to project repo
# =============================================================================
# purpose: writes a lightweight .claude/breadcrumbs.md into the project repo at session end so the next session can locate relevant vault notes
# inputs: stdin JSON with session_id; CLAUDE_PROJECT_DIR or PWD; CLAUDE_AUTOMATED env var; sources detect-org.sh
# outputs: .claude/breadcrumbs.md written to the project repo root
# side-effects: creates .claude/ directory if absent; skips if not inside a git repo or if CLAUDE_AUTOMATED=1
# =============================================================================

INPUT=$(cat)

# Guard: skip in automated/cron-triggered sessions.
# ${VAR:-} form required — bare $CLAUDE_AUTOMATED aborts under `set -u` in
# any normal interactive session where the var is unset.
[[ "${CLAUDE_AUTOMATED:-}" == "1" ]] && exit 0

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
