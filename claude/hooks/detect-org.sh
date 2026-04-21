#!/bin/bash
set -euo pipefail
# =============================================================================
# detect-org.sh — Maps working directory to org identifier
# =============================================================================
# purpose: resolves the current working directory to an org name, vault folder, and wikilink using org-map.json; longest-match-wins so /lxs/persimmon resolves to Persimmon not LXS
# inputs: CLAUDE_PROJECT_DIR or PWD; ORG_MAP path from env.sh; sourced by other hooks
# outputs: exports DETECTED_ORG, DETECTED_ORG_FOLDER, DETECTED_WIKILINK
# side-effects: none; safe to source multiple times
# =============================================================================

source "$HOME/.claude/env.sh"

CWD_LOWER=$(echo "${CLAUDE_PROJECT_DIR:-$PWD}" | tr '[:upper:]' '[:lower:]')

# Pre-initialise so `set -u` doesn't abort callers when ORG_MAP is missing
# and the jq branch below is skipped.
DETECTED_ORG=""

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
