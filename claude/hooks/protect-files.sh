#!/bin/bash
# =============================================================================
# GODL1KE protect-files.sh — Block Edits to Sensitive Files
# =============================================================================
# WHY: Some files should NEVER be edited by Claude — credentials, keys,
# SSH configs. This hook checks the file path against protected patterns
# and blocks with exit 2 if matched.
#
# Location: ~/.claude/hooks/protect-files.sh
# Triggered by: PreToolUse → Write|Edit|MultiEdit
# =============================================================================

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# MultiEdit has an array of paths; Write/Edit have a single file_path
if [ "$TOOL_NAME" = "MultiEdit" ]; then
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.edits[].file_path // empty' 2>/dev/null)
else
  FILE_PATHS=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

# Guard: no file path
if [ -z "$FILE_PATHS" ]; then
  exit 0
fi

# Protected file patterns
PROTECTED_PATTERNS=(
  ".env"
  ".pem"
  ".key"
  ".p12"
  ".pfx"
  "credentials"
  "secrets"
  "id_rsa"
  "id_ed25519"
  ".ssh/config"
  ".aws/credentials"
  ".azure/credentials"
  "serviceAccountKey"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  while IFS= read -r FILE_PATH; do
    [ -z "$FILE_PATH" ] && continue
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
      # Allow .env.example / .env.sample / .env.template — these are reference files, not secrets
      if [[ "$pattern" == ".env" ]]; then
        BASENAME_CHECK=$(basename "$FILE_PATH")
        if [[ "$BASENAME_CHECK" == ".env.example" || "$BASENAME_CHECK" == ".env.sample" || "$BASENAME_CHECK" == ".env.template" ]]; then
          continue
        fi
      fi
      echo "BLOCKED: '$FILE_PATH' matches protected pattern '$pattern'. Edit this file manually." >&2
      exit 2
    fi
  done <<< "$FILE_PATHS"
done

exit 0
