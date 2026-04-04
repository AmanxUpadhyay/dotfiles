#!/bin/bash
# =============================================================================
# GODL1KE session-start.sh — Inject Git + Obsidian Context at Session Start
# =============================================================================
# Injects:
#   1. Git context (branch, recent commits, changed files)
#   2. Org detection (maps working directory to client/startup)
#   3. Obsidian context (most recent session note + org context file)
#   4. Breadcrumb from repo (if exists)
# =============================================================================

VAULT="/Users/godl1ke/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE"
CONTEXT=""

# ---------------------------------------------------------------------------
# 1. Git context
# ---------------------------------------------------------------------------
if git rev-parse --is-inside-work-tree &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  RECENT_COMMITS=$(git log --oneline -5 2>/dev/null)
  CHANGED_FILES=$(git diff --name-only 2>/dev/null)
  STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)
  STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

  GIT_CTX="Git Context:
• Branch: $BRANCH
• Recent commits:
$RECENT_COMMITS"

  [[ -n "$CHANGED_FILES" ]] && GIT_CTX="$GIT_CTX
• Uncommitted changes:
$CHANGED_FILES"

  [[ -n "$STAGED_FILES" ]] && GIT_CTX="$GIT_CTX
• Staged for commit:
$STAGED_FILES"

  [[ "$STASH_COUNT" -gt 0 ]] && GIT_CTX="$GIT_CTX
• Stashed changes: $STASH_COUNT"

  CONTEXT="$GIT_CTX"
fi

# ---------------------------------------------------------------------------
# 2. Org detection
# ---------------------------------------------------------------------------
source "$HOME/.claude/hooks/detect-org.sh"
CONTEXT="$CONTEXT

## Organisation: $DETECTED_ORG
Obsidian vault available via mcp__obsidian tools (vault: GODL1KE).
Session notes → 06-Sessions/$DETECTED_ORG/
Decision records → org Decisions/ folder
Bug fixes → 04-Knowledge/Bug-Jar/"

# ---------------------------------------------------------------------------
# 3. Obsidian: most recent session note for this org
# ---------------------------------------------------------------------------
SESSION_DIR="$VAULT/06-Sessions/$DETECTED_ORG_FOLDER"
if [[ -d "$SESSION_DIR" ]]; then
  LATEST=$(ls -t "$SESSION_DIR"/*.md 2>/dev/null | head -1)
  if [[ -n "$LATEST" && -f "$LATEST" ]]; then
    SESSION_CONTENT=$(head -60 "$LATEST")
    CONTEXT="$CONTEXT

## Last Session ($DETECTED_ORG)
$SESSION_CONTENT"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Obsidian: org context file (living spec)
# ---------------------------------------------------------------------------
# Check common locations for context.md
for CANDIDATE in \
  "$VAULT/02-Startups/$DETECTED_ORG_FOLDER/context.md" \
  "$VAULT/03-Clients/$DETECTED_ORG_FOLDER/context.md" \
  "$VAULT/01-LXS/$DETECTED_ORG_FOLDER/context.md" \
  "$VAULT/06-Sessions/$DETECTED_ORG_FOLDER/context.md"; do
  if [[ -f "$CANDIDATE" ]]; then
    CONTEXT_CONTENT=$(head -80 "$CANDIDATE")
    CONTEXT="$CONTEXT

## Project Context ($DETECTED_ORG)
$CONTEXT_CONTENT"
    break
  fi
done

# ---------------------------------------------------------------------------
# 5. Breadcrumb from repo (if exists)
# ---------------------------------------------------------------------------
BREADCRUMB="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/breadcrumbs.md"
if [[ -f "$BREADCRUMB" ]]; then
  CRUMB=$(cat "$BREADCRUMB")
  CONTEXT="$CONTEXT

## Repo Breadcrumbs
$CRUMB"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": $(echo "$CONTEXT" | jq -Rs .)}}"
exit 0
