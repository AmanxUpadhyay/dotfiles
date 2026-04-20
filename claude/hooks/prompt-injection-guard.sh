#!/bin/bash
set -euo pipefail
# =============================================================================
# prompt-injection-guard.sh — Reject Obvious Prompt Injection Attempts
# =============================================================================
# purpose: scans each user prompt against a pattern list of known injection attempts and blocks them before they reach Claude
# inputs: stdin JSON with prompt field from UserPromptSubmit event
# outputs: exit 2 with stderr message if injection detected; exit 0 to allow prompt through
# side-effects: none; case-insensitive pattern matching only
# =============================================================================

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

PATTERNS=(
  'ignore (all )?(previous|above|prior) instructions'
  'disregard (all )?(previous|above|prior) instructions'
  'forget (everything|all instructions)'
  'new (system |)prompt:'
  'system override'
  'admin mode (enabled|activated|on)'
  'developer mode (enabled|activated|on)'
  'bypass (all |your |safety |)restrictions'
  'ignore (all |your |safety |)restrictions'
  'jailbreak'
  'DAN mode'
  '\[SYSTEM\]'
  '\[ADMIN\]'
  '\[OVERRIDE\]'
  'send (this|all|my) (conversation|chat|messages|history) to'
  'upload (my|all) files? to'
)

for pattern in "${PATTERNS[@]}"; do
  if echo "$PROMPT" | grep -qiE "$pattern"; then
    echo "BLOCKED [injection-guard]: Potential injection pattern detected: '$pattern'" >&2
    echo "If this is a legitimate request, rephrase it." >&2
    exit 2
  fi
done

exit 0
