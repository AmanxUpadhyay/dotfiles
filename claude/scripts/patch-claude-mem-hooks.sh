#!/bin/bash
# =============================================================================
# patch-claude-mem-hooks.sh — Self-healing patcher for claude-mem plugin hooks
# =============================================================================
# purpose: claude-mem's UserPromptSubmit and other observer hooks exit 1 with
#   no stderr when the worker health probe fails (upstream issues #2090,
#   #2095). This script appends ` || true` to every observer-hook command in
#   every installed version of the plugin so Claude Code never surfaces the
#   error to the user. Idempotent; runs at SessionStart and can be invoked
#   manually on any hooks.json file.
# inputs: optional path to a hooks.json; if omitted, scans every
#   hooks.json under ~/.claude/plugins/cache/thedotmack/claude-mem/
# outputs: atomic rewrite of each target file (only if changes needed).
#   Appends a summary line per invocation to
#   $CLAUDE_LOG_DIR/claude-mem-patcher.log (falls back to
#   ~/Library/Logs/claude-crons/).
# side-effects: modifies hooks.json files in-place via tmpfile+rename.
#   Always exits 0 (fail-open — never blocks a session).
# =============================================================================

# Note: intentionally NOT using `set -euo pipefail`. This script is invoked
# from SessionStart where an abort would be worse than a silent skip. We
# handle failures explicitly and always exit 0.

LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/Library/Logs/claude-crons}"
LOG_FILE="$LOG_DIR/claude-mem-patcher.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
  # Fire-and-forget logger; never fail the caller on log-write errors.
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

# The Python patcher lives as a heredoc so we ship one file, not two.
# Target paths are passed as argv (stdin is consumed by the heredoc itself).
run_python_patch() {
  python3 - "$@" <<'PYEOF'
import json, os, sys, tempfile

OBSERVER_EVENTS = {
    "UserPromptSubmit",
    "PostToolUse",
    "Stop",
    "PreToolUse",
    "SessionEnd",
}
TAIL = " || true"


def patch_file(path: str) -> tuple[bool, int]:
    """Return (changed, commands_patched)."""
    try:
        with open(path, "r", encoding="utf-8") as fp:
            data = json.load(fp)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"skip {path}: {exc}", file=sys.stderr)
        return (False, 0)

    hooks = data.get("hooks", {})
    if not isinstance(hooks, dict):
        return (False, 0)

    patched = 0
    for event_name, groups in hooks.items():
        if event_name not in OBSERVER_EVENTS:
            continue
        if not isinstance(groups, list):
            continue
        for group in groups:
            if not isinstance(group, dict):
                continue
            for hook in group.get("hooks", []) or []:
                if not isinstance(hook, dict):
                    continue
                if hook.get("type") != "command":
                    continue
                cmd = hook.get("command")
                if not isinstance(cmd, str):
                    continue
                stripped = cmd.rstrip()
                if stripped.endswith(TAIL.strip()):
                    # Already patched (accept both " || true" and "|| true").
                    continue
                hook["command"] = stripped + TAIL
                patched += 1

    if patched == 0:
        return (False, 0)

    # Atomic write: tmpfile in same dir + rename.
    dirpath = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".hooks.json.", dir=dirpath)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fp:
            json.dump(data, fp, indent=2)
            fp.write("\n")
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return (True, patched)


targets = [arg for arg in sys.argv[1:] if arg]
total_changed = 0
total_commands = 0
for t in targets:
    if not os.path.isfile(t):
        print(f"skip {t}: not a file", file=sys.stderr)
        continue
    try:
        changed, n = patch_file(t)
    except Exception as exc:
        print(f"error {t}: {exc}", file=sys.stderr)
        continue
    if changed:
        total_changed += 1
        total_commands += n
        print(f"patched {t}: {n} command(s)", file=sys.stderr)

print(f"summary: files_changed={total_changed} commands_patched={total_commands}")
PYEOF
}

# Collect target paths — either the single path argument or scan the cache tree.
collect_targets() {
  if [ $# -gt 0 ]; then
    for arg in "$@"; do
      printf '%s\n' "$arg"
    done
    return 0
  fi
  local root="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
  [ -d "$root" ] || return 0
  # `find` never fails fatally for us; suppress its stderr to keep the log clean.
  find "$root" -type f -name hooks.json 2>/dev/null
}

main() {
  log "run start argv=$* user=$(id -un 2>/dev/null || echo ?)"
  # Gather targets into a bash array so paths with spaces survive intact.
  local -a targets=()
  while IFS= read -r line; do
    [ -n "$line" ] && targets+=("$line")
  done < <(collect_targets "$@")
  if [ ${#targets[@]} -eq 0 ]; then
    log "no hooks.json found; nothing to patch"
    return 0
  fi
  # Pass paths as argv; capture summary for the log.
  local summary
  summary=$(run_python_patch "${targets[@]}" 2>&1)
  log "$summary"
  return 0
}

main "$@"
# Always exit 0 — observer script, must never break a session.
exit 0
