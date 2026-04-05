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

while IFS= read -r FILE_PATH; do
  [ -z "$FILE_PATH" ] && continue
  BASENAME=$(basename "$FILE_PATH")

  # --- Extension patterns: match only if basename ends with the extension ---
  # Prevents false positives like keyboard.key.ts, privatekey_test.py
  for ext in ".pem" ".p12" ".pfx"; do
    if [[ "$BASENAME" == *"$ext" ]]; then
      echo "BLOCKED: '$FILE_PATH' has protected extension '$ext'. Edit this file manually." >&2
      exit 2
    fi
  done

  # .key extension: only block if basename ends with .key (not .key.ts, .key.json etc.)
  if [[ "$BASENAME" =~ \.key$ ]]; then
    echo "BLOCKED: '$FILE_PATH' has protected extension '.key'. Edit this file manually." >&2
    exit 2
  fi

  # --- Dotenv: block .env, .env.local, .env.production etc. ---
  # Allow .env.example, .env.sample, .env.template (reference/documentation files)
  if [[ "$BASENAME" == .env || "$BASENAME" == .env.* ]]; then
    case "$BASENAME" in
      .env.example|.env.sample|.env.template)
        : # Allow — these are documentation files, not secrets
        ;;
      *)
        echo "BLOCKED: '$FILE_PATH' is an environment secrets file. Edit this file manually." >&2
        exit 2
        ;;
    esac
  fi

  # --- Exact basename match (with optional extension): credentials.json blocked,
  # credentials_test.py allowed. Uses regex for basename == pattern or pattern.ext ---
  for secret in "credentials" "secrets" "id_rsa" "id_ed25519"; do
    if [[ "$BASENAME" == "$secret" || "$BASENAME" == "$secret."* ]]; then
      echo "BLOCKED: '$FILE_PATH' matches protected filename '$secret'. Edit this file manually." >&2
      exit 2
    fi
  done

  # --- Path suffix: match against the full path ending ---
  for suffix in ".ssh/config" ".aws/credentials" ".azure/credentials"; do
    if [[ "$FILE_PATH" == *"$suffix" ]]; then
      echo "BLOCKED: '$FILE_PATH' matches protected path '$suffix'. Edit this file manually." >&2
      exit 2
    fi
  done

  # --- Basename contains: substring match on basename only ---
  if [[ "$BASENAME" == *"serviceAccountKey"* ]]; then
    echo "BLOCKED: '$FILE_PATH' contains 'serviceAccountKey' in filename. Edit this file manually." >&2
    exit 2
  fi

done <<< "$FILE_PATHS"

exit 0
