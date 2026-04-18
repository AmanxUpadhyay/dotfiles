#!/bin/bash
# =============================================================================
# install-launchagents.sh — Install Claude automation as launchd user agents
# =============================================================================
# Symlinks plist files into ~/Library/LaunchAgents/ and loads them.
# Run this after cloning dotfiles or whenever plists change.
# To uninstall, run with: ./install-launchagents.sh --uninstall
# =============================================================================

set -euo pipefail

AGENTS_SRC="$HOME/.dotfiles/claude/launchagents"
AGENTS_DST="$HOME/Library/LaunchAgents"
GUI_DOMAIN="gui/$(id -u)"

UNINSTALL=false
[[ "${1:-}" == "--uninstall" ]] && UNINSTALL=true

mkdir -p "$AGENTS_DST"

for plist in "$AGENTS_SRC"/com.godl1ke.claude.*.plist; do
    [[ -f "$plist" ]] || continue
    name=$(basename "$plist" .plist)
    dst="$AGENTS_DST/$(basename "$plist")"

    # Unload if currently loaded (ignore errors — may not be loaded yet)
    launchctl bootout "$GUI_DOMAIN/$name" 2>/dev/null || true

    if [[ "$UNINSTALL" == true ]]; then
        rm -f "$dst"
        echo "Uninstalled: $name"
        continue
    fi

    # Symlink from dotfiles source
    ln -sf "$plist" "$dst"

    # Load into the user session
    launchctl bootstrap "$GUI_DOMAIN" "$dst"
    echo "Loaded: $name"
done

if [[ "$UNINSTALL" == false ]]; then
    echo ""
    echo "All agents loaded. Verify with:"
    echo "  launchctl print $GUI_DOMAIN | grep godl1ke.claude"
    echo ""
    echo "Test-fire an agent with:"
    echo "  launchctl kickstart $GUI_DOMAIN/com.godl1ke.claude.healthcheck-preflight"
fi
