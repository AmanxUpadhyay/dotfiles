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
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Guard: no file path
if [ -z "$FILE_PATH" ]; then
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
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "BLOCKED: '$FILE_PATH' matches protected pattern '$pattern'. Edit this file manually." >&2
    exit 2
  fi
done

exit 0
