#!/bin/bash
# =============================================================================
# detect-org.sh — Maps working directory to org identifier
# =============================================================================
# Source this file in other hooks. Sets $DETECTED_ORG, $DETECTED_ORG_FOLDER,
# and $DETECTED_WIKILINK from the orgs section of org-map.json.
#
# Longest-match-wins: if /lxs/persimmon is the cwd, "persimmon" (7 chars)
# wins over "/lxs" (4 chars), so org is Persimmon not LXS.
# =============================================================================

source "$HOME/.claude/env.sh"

CWD_LOWER=$(echo "${CLAUDE_PROJECT_DIR:-$PWD}" | tr '[:upper:]' '[:lower:]')

if [[ -f "$ORG_MAP" ]]; then
  DETECTED_ORG=$(jq -r --arg cwd "$CWD_LOWER" '
    [ .mappings[] | select(.path_contains as $p | $cwd | contains($p)) ]
    | sort_by(.path_contains | length) | reverse
    | .[0].org // empty
  ' "$ORG_MAP" 2>/dev/null)
fi

if [[ -z "$DETECTED_ORG" ]]; then
  DETECTED_ORG=$(jq -r '.default_org' "$ORG_MAP" 2>/dev/null || echo "Personal")
fi

# Read wikilink and vault_folder from orgs section
DETECTED_WIKILINK=$(jq -r --arg org "$DETECTED_ORG" '.orgs[$org].wikilink // "[[VAULT]]"' "$ORG_MAP" 2>/dev/null)
DETECTED_ORG_FOLDER=$(jq -r --arg org "$DETECTED_ORG" '.orgs[$org].vault_folder // $org' "$ORG_MAP" 2>/dev/null)

export DETECTED_ORG
export DETECTED_ORG_FOLDER
export DETECTED_WIKILINK
