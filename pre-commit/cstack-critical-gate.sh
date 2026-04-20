#!/bin/bash
#
# purpose: Block commit when cstack-audit surfaces any Critical finding.
# inputs:  stdin ignored; operates against current ~/.dotfiles tree.
# outputs: human-readable error to stderr on block; nothing on pass.
# side-effects: none. Tool runs in quick mode (inventory + cross_cutting only).
#
# Opt out: SKIP_CSTACK=1 git commit ...

set -euo pipefail

# Opt-out escape hatch
if [[ "${SKIP_CSTACK:-0}" == "1" ]]; then
  exit 0
fi

# Skip if tool isn't installed (fresh clone, uv not run yet)
if ! command -v cstack-audit >/dev/null 2>&1; then
  echo "cstack-audit: not installed; skipping pre-commit gate" >&2
  echo "  (run install.sh or: uv tool install -e ~/.dotfiles/claude-stack-audit)" >&2
  exit 0
fi

# Run a fast subset. Exit code:
#   0 = no Critical/High
#   1 = has Critical or High (we still let High through; only block Critical)
#   2 = env validation failed (we skip, don't block commits on that)
#   3 = a check crashed (we skip too)

# Capture output so we can inspect Critical count without running the full tool twice.
# --quick limits to inventory + cross_cutting (sub-second).
# --only cross_cutting further narrows to the criterion that produces Critical findings.

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Run; capture both stdout and stderr. Non-zero exit is expected.
if cstack-audit run --quick --only cross_cutting > "$TMP" 2>&1; then
  RC=0
else
  RC=$?
fi

# If validate (RC=2) or crash (RC=3) — warn but don't block commits
if [[ "$RC" == "2" || "$RC" == "3" ]]; then
  echo "cstack-audit: pre-commit gate skipped (rc=$RC)" >&2
  cat "$TMP" >&2
  exit 0
fi

# Parse the summary line to detect Critical findings.
# Format: "N findings (X Critical, Y High, ...). Score: Z/1000."
SUMMARY=$(grep -E '^[0-9]+ findings' "$TMP" || true)
CRITICAL=$(printf '%s' "$SUMMARY" | sed -nE 's/.*\(([0-9]+) Critical.*/\1/p')

if [[ -z "$CRITICAL" ]]; then
  # Tool output format didn't match — pass through rather than false-block.
  exit 0
fi

if [[ "$CRITICAL" -gt 0 ]]; then
  echo "cstack-audit: blocking commit — $CRITICAL Critical finding(s)" >&2
  echo "" >&2
  cat "$TMP" >&2
  echo "" >&2
  echo "Override with SKIP_CSTACK=1 git commit (not recommended)." >&2
  exit 1
fi

exit 0
