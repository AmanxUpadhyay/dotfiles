#!/bin/bash
# =============================================================================
# detect-org.sh — Maps working directory to org identifier
# =============================================================================
# Source this file in other hooks. Sets $DETECTED_ORG.
# Reads mappings from ~/.claude/org-map.json (path_contains matching).
# =============================================================================

ORG_MAP="$HOME/.claude/org-map.json"
CWD_LOWER=$(echo "${CLAUDE_PROJECT_DIR:-$PWD}" | tr '[:upper:]' '[:lower:]')

if [[ -f "$ORG_MAP" ]]; then
  DETECTED_ORG=$(jq -r --arg cwd "$CWD_LOWER" '
    .mappings[] | select(.path_contains as $p | $cwd | contains($p)) | .org
  ' "$ORG_MAP" 2>/dev/null | head -1)
  DETECTED_ORG_FOLDER=$(jq -r --arg cwd "$CWD_LOWER" '
    .mappings[] | select(.path_contains as $p | $cwd | contains($p)) | .vault_folder // .org
  ' "$ORG_MAP" 2>/dev/null | head -1)
fi

if [[ -z "$DETECTED_ORG" ]]; then
  DETECTED_ORG=$(jq -r '.default_org' "$ORG_MAP" 2>/dev/null || echo "General")
fi

if [[ -z "$DETECTED_ORG_FOLDER" ]]; then
  DETECTED_ORG_FOLDER="$DETECTED_ORG"
fi

export DETECTED_ORG
export DETECTED_ORG_FOLDER
