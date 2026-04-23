# ~/.zshenv — environment for every zsh invocation (interactive, login, non-interactive).
#
# Keep this file intentionally minimal. zshenv runs before anything else and is
# sourced even by non-interactive subshells, so heavy logic or strict-mode
# errors here can break every script on the system.
#
# Canonical env definitions live in ~/.dotfiles/claude/env.sh (bash, sourced by
# hooks/crons). env.sh uses `set -euo pipefail` and therefore CANNOT be sourced
# directly from zsh startup without risking abort-on-first-failure.
#
# The single line below mirrors env.sh so Claude Code, when launched from this
# shell, exports CLAUDE_MEM_WORKER_PORT into every hook subprocess it spawns.
# Without this, the claude-mem plugin's per-prompt hook falls back to reading
# ~/.claude-mem/settings.json, which may drift from the worker's bind port and
# cause "UserPromptSubmit hook error: Failed with non-blocking status code".
# Tests in tests/zshenv_port_sync.bats keep the formula aligned with env.sh:41.
export CLAUDE_MEM_WORKER_PORT="${CLAUDE_MEM_WORKER_PORT:-$((37700 + $(id -u 2>/dev/null || echo 77) % 100))}"
