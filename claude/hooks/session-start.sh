#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.claude/libs/hooks-log.sh" ]]; then
  source "$HOME/.claude/libs/hooks-log.sh"
  log_hook_fire "SessionStart"
fi
# =============================================================================
# session-start.sh — Inject Git + Obsidian Context at Session Start
# =============================================================================
# purpose: injects git context, org detection, recent Obsidian session notes, org context file, and repo breadcrumbs into the session as additionalContext
# inputs: OBSIDIAN_VAULT, ORG_MAP from env.sh; CLAUDE_PROJECT_DIR or PWD; git repo state; Obsidian vault files
# outputs: JSON hookSpecificOutput with SessionStart additionalContext block printed to stdout
# side-effects: self-heals plugin symlinks in ~/.claude/plugins/cache if broken; reads vault files and git state
# =============================================================================

source "$HOME/.claude/env.sh"

# ---------------------------------------------------------------------------
# 0. Self-heal: ensure all cached plugins have their marketplaces/ symlink
#    Fixes the thedotmack/claude-mem pattern where upgrades delete the old
#    symlink but fail to recreate it, causing stop-hook errors next session.
# ---------------------------------------------------------------------------
PLUGIN_CACHE="$HOME/.claude/plugins/cache"
PLUGIN_MKT="$HOME/.claude/plugins/marketplaces"
if [[ -d "$PLUGIN_CACHE" ]]; then
  for author_dir in "$PLUGIN_CACHE"/*/; do
    [[ -d "$author_dir" ]] || continue  # skip literal glob when author_dir has no matches
    author=$(basename "$author_dir")
    for plugin_dir in "$author_dir"*/; do
      [[ -d "$plugin_dir" ]] || continue  # skip literal glob when plugin_dir has no matches
      _plugin=$(basename "$plugin_dir")  # intentionally unused: loop iterates dirs, target path uses author
      target="$PLUGIN_MKT/$author/plugin"
      if [[ ! -e "$target" ]]; then
        # Find the latest version in cache (sort -V for semantic versioning).
        # `|| true` protects against pipefail when the ls glob finds nothing.
        latest=$(ls -d "$plugin_dir"*/ 2>/dev/null | sort -V | tail -1 || true)
        if [[ -n "$latest" ]]; then
          mkdir -p "$PLUGIN_MKT/$author"
          ln -sf "$latest" "$target"
        fi
      fi
    done
  done
fi

VAULT="$OBSIDIAN_VAULT"
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
# Check common locations for org context file (named after org, e.g. LXS.md, AdTecher.md)
for CANDIDATE in \
  "$VAULT/02-Startups/$DETECTED_ORG_FOLDER/$DETECTED_ORG_FOLDER.md" \
  "$VAULT/03-Clients/$DETECTED_ORG_FOLDER/$DETECTED_ORG_FOLDER.md" \
  "$VAULT/01-LXS/$DETECTED_ORG_FOLDER/$DETECTED_ORG_FOLDER.md" \
  "$VAULT/01-LXS/$DETECTED_ORG.md"; do
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
# 6. claude-mem: relevant past observations for this project
# ---------------------------------------------------------------------------
# Explicit HTTP query to the claude-mem worker (localhost:37777). Takes over
# injection from the plugin's IMPORTANT tool convention, which Claude wasn't
# reliably self-calling at session start. Fails open — worker down or slow
# just skips the section, never fails SessionStart.
CLAUDE_MEM_SCOPE=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  CLAUDE_MEM_SCOPE=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "")
fi
[[ -z "$CLAUDE_MEM_SCOPE" ]] && CLAUDE_MEM_SCOPE="${DETECTED_ORG:-}"

if [[ -n "$CLAUDE_MEM_SCOPE" ]]; then
  MEM_QUERY=$(printf '%s' "$CLAUDE_MEM_SCOPE" | sed 's/[^a-zA-Z0-9._-]/%20/g')
  MEM_RAW=$(curl -sS --max-time 2 "http://127.0.0.1:37777/api/search?query=$MEM_QUERY&limit=5" 2>/dev/null || echo "")
  if [[ -n "$MEM_RAW" ]]; then
    MEM_TEXT=$(echo "$MEM_RAW" | jq -r '.content[0].text // empty' 2>/dev/null || echo "")
    if [[ -n "$MEM_TEXT" ]]; then
      CONTEXT="$CONTEXT

## Past Context (claude-mem, scope=$CLAUDE_MEM_SCOPE)
$MEM_TEXT"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": $(echo "$CONTEXT" | jq -Rs .)}}"
exit 0
