#!/bin/bash
# =============================================================================
# GODL1KE session-start.sh — Inject Git Context at Session Start
# =============================================================================
# WHY: When you start a Claude Code session, Claude has zero context about
# where you are in the codebase. This hook injects the current branch,
# recent commits, and changed files so Claude knows what's happening
# from the very first prompt. No more "what branch am I on?" questions.
#
# Location: ~/.claude/hooks/session-start.sh
# Triggered by: SessionStart → startup
# =============================================================================

# Guard: not in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null)
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null)
CHANGED_FILES=$(git diff --name-only 2>/dev/null)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

CONTEXT="Git Context:
• Branch: $BRANCH
• Recent commits:
$RECENT_COMMITS"

if [ -n "$CHANGED_FILES" ]; then
  CONTEXT="$CONTEXT
• Uncommitted changes:
$CHANGED_FILES"
fi

if [ -n "$STAGED_FILES" ]; then
  CONTEXT="$CONTEXT
• Staged for commit:
$STAGED_FILES"
fi

if [ "$STASH_COUNT" -gt 0 ]; then
  CONTEXT="$CONTEXT
• Stashed changes: $STASH_COUNT"
fi

echo "{\"additionalContext\": $(echo "$CONTEXT" | jq -Rs .)}"

exit 0
