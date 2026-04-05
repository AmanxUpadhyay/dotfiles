#!/bin/bash
# =============================================================================
# env.sh — Shared environment variables for Claude Code hooks and cron scripts
# =============================================================================
# Source this file from any hook or cron script that needs these variables.
# Symlinked at ~/.claude/env.sh -> ~/.dotfiles/claude/env.sh
# =============================================================================

export OBSIDIAN_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE"
export CLAUDE_BIN="${CLAUDE_BIN:-/Users/godl1ke/.npm-packages/bin/claude}"
export CLAUDE_LOG_DIR="$HOME/Library/Logs/claude-crons"
export ORG_MAP="$HOME/.claude/org-map.json"
