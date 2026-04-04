#!/bin/bash
# =============================================================================
# GODL1KE Raycast Project Switcher
# =============================================================================
# WHY: Open Raycast → type the project name → instantly jump to a tmux
# session in that project directory. Much faster than cd + claude.
#
# SETUP:
#   1. Open Raycast → Extensions → Script Commands → Add Directory
#   2. Point to this directory (~/.dotfiles/raycast/)
#   3. Each script appears as a Raycast command
#
# Alternative: Import these as Raycast Quicklinks:
#   Raycast → Quicklinks → + → Shell Command
# =============================================================================

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Switch Project
# @raycast.mode silent
# @raycast.packageName GODL1KE

# Optional parameters:
# @raycast.icon 🚀
# @raycast.argument1 { "type": "dropdown", "placeholder": "Project", "data": [{"title": "LXS", "value": "lxs"}, {"title": "Persimmon", "value": "persimmon"}, {"title": "AdTecher", "value": "adtecher"}, {"title": "Wayv", "value": "wayv"}, {"title": "ClubRevAI", "value": "clubrevai"}, {"title": "Ledgx", "value": "ledgx"}] }

PROJECT="$1"

case "$PROJECT" in
  lxs)       DIR="$HOME/projects/lxs" ;;
  persimmon) DIR="$HOME/projects/persimmon-homes" ;;
  adtecher)  DIR="$HOME/projects/adtecher" ;;
  wayv)      DIR="$HOME/projects/wayv" ;;
  clubrevai) DIR="$HOME/projects/clubrevai" ;;
  ledgx)     DIR="$HOME/projects/ledgx" ;;
  *)         echo "Unknown project: $PROJECT"; exit 1 ;;
esac

# Create tmux session if it doesn't exist
if ! tmux has-session -t "$PROJECT" 2>/dev/null; then
  tmux new-session -d -s "$PROJECT" -c "$DIR"
fi

# Open Ghostty with the tmux session
open -a Ghostty
sleep 0.5
tmux switch-client -t "$PROJECT" 2>/dev/null || tmux attach-session -t "$PROJECT"
