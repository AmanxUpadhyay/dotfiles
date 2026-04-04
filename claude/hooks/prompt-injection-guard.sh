#!/bin/bash
# UserPromptSubmit hook — reject obvious injection attempts before they reach Claude.
# Exit 2 = reject prompt (stderr shown to user). Exit 0 = allow.

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

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
  if echo "$PROMPT_LOWER" | grep -qiE "$pattern"; then
    echo "BLOCKED [injection-guard]: Potential injection pattern detected: '$pattern'" >&2
    echo "If this is a legitimate request, rephrase it." >&2
    exit 2
  fi
done

exit 0
