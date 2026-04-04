#!/bin/bash
# =============================================================================
# GODL1KE install.sh — Master Install Script
# =============================================================================
# WHY: Automates the entire fresh Mac setup. Run this after formatting.
# It's idempotent — safe to run multiple times. Each section checks if
# the tool is already installed before proceeding.
#
# USAGE:
#   chmod +x install.sh
#   ./install.sh
#
# PREREQUISITES: macOS fresh install, internet connection
# TIME: ~15-30 minutes depending on download speeds
# =============================================================================

set -e  # Exit on any error

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "🚀 GODL1KE Setup — Starting from $DOTFILES_DIR"
echo "=================================================="

# -----------------------------------------------------------------------------
# Phase 1: macOS Foundation
# -----------------------------------------------------------------------------
echo ""
echo "📦 Phase 1: macOS Foundation"
echo "----------------------------"

# Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "⏳ Waiting for Xcode CLT install to complete. Press ENTER when done."
  read -r
else
  echo "✅ Xcode CLT already installed"
fi

# Homebrew
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "✅ Homebrew already installed"
fi

# Brew Bundle
echo "Installing packages from Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock

# macOS defaults
echo "Setting macOS defaults..."
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 48
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

# -----------------------------------------------------------------------------
# Phase 2: Shell & Terminal
# -----------------------------------------------------------------------------
echo ""
echo "🐚 Phase 2: Shell & Terminal"
echo "----------------------------"

# Starship config
mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/starship/starship.toml" ~/.config/starship.toml
echo "✅ Starship config linked"

# Ghostty config
mkdir -p ~/.config/ghostty
ln -sf "$DOTFILES_DIR/ghostty/config" ~/.config/ghostty/config
echo "✅ Ghostty config linked"

# zshrc
ln -sf "$DOTFILES_DIR/zsh/.zshrc" ~/.zshrc
echo "✅ .zshrc linked"

# tmux
ln -sf "$DOTFILES_DIR/tmux/.tmux.conf" ~/.tmux.conf
echo "✅ .tmux.conf linked"

# -----------------------------------------------------------------------------
# Phase 3: Git
# -----------------------------------------------------------------------------
echo ""
echo "🔀 Phase 3: Git"
echo "----------------"

ln -sf "$DOTFILES_DIR/git/.gitconfig" ~/.gitconfig
ln -sf "$DOTFILES_DIR/git/.gitignore_global" ~/.gitignore_global
echo "✅ Git config linked"

# SSH key for signed commits
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "Generating SSH key for signed commits..."
  echo "Enter your email for the SSH key:"
  read -r EMAIL
  ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519
  echo ""
  echo "⚠️  Add this public key to GitHub:"
  echo "   1. gh auth login"
  echo "   2. gh ssh-key add ~/.ssh/id_ed25519.pub --title 'GODL1KE M2 Max'"
  echo "   3. Go to GitHub Settings → SSH and GPG keys → enable signing"
else
  echo "✅ SSH key already exists"
fi

# gh CLI auth
if ! gh auth status &>/dev/null; then
  echo "Authenticating GitHub CLI..."
  gh auth login
else
  echo "✅ GitHub CLI already authenticated"
fi

# -----------------------------------------------------------------------------
# Phase 4: Python
# -----------------------------------------------------------------------------
echo ""
echo "🐍 Phase 4: Python"
echo "-------------------"

echo "Python version: $(python3 --version)"
echo "uv version: $(uv --version)"

# Global Python tools
uv tool install pip-audit 2>/dev/null || echo "✅ pip-audit already installed"

# -----------------------------------------------------------------------------
# Phase 5: Claude Code
# -----------------------------------------------------------------------------
echo ""
echo "🤖 Phase 5: Claude Code"
echo "------------------------"

# Install Claude Code
if ! command -v claude &>/dev/null; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "✅ Claude Code already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
fi

# Claude config directories
mkdir -p ~/.claude/{hooks,agents,commands}

# Global CLAUDE.md
ln -sf "$DOTFILES_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md
echo "✅ Global CLAUDE.md linked"

# Settings (hooks)
ln -sf "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json
echo "✅ Global settings.json linked"

# Hook scripts
for hook in "$DOTFILES_DIR"/claude/hooks/*.sh; do
  BASENAME=$(basename "$hook")
  ln -sf "$hook" ~/.claude/hooks/"$BASENAME"
  chmod +x "$hook"
done
echo "✅ Hook scripts linked and made executable"

# Agent definitions
for agent in "$DOTFILES_DIR"/claude/agents/*.md; do
  BASENAME=$(basename "$agent")
  ln -sf "$agent" ~/.claude/agents/"$BASENAME"
done
echo "✅ Agent definitions linked"

# Slash commands
for cmd in "$DOTFILES_DIR"/claude/commands/*.md; do
  BASENAME=$(basename "$cmd")
  ln -sf "$cmd" ~/.claude/commands/"$BASENAME"
done
echo "✅ Slash commands linked"

# MCP config — merge into ~/.claude.json
echo ""
echo "⚠️  MCP server config needs manual setup:"
echo "   1. Copy claude-json/claude.json content into ~/.claude.json"
echo "   2. Remove all _comment and _note fields"
echo "   3. Replace VAULT_PATH_PLACEHOLDER with your Obsidian vault path"
echo "   4. Run: claude mcp add --transport http linear https://mcp.linear.app/mcp"

# -----------------------------------------------------------------------------
# Phase 6: Project Directories
# -----------------------------------------------------------------------------
echo ""
echo "📁 Phase 6: Project Directories"
echo "--------------------------------"

mkdir -p ~/projects
echo "✅ ~/projects directory created"
echo ""
echo "Clone your repos into ~/projects/:"
echo "   cd ~/projects && gh repo clone <org>/<repo>"

# -----------------------------------------------------------------------------
# Phase 7: Obsidian Vault
# -----------------------------------------------------------------------------
echo ""
echo "📝 Phase 7: Obsidian"
echo "---------------------"

VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/GODL1KE"
if [ ! -d "$VAULT" ]; then
  echo "Creating GODL1KE vault structure..."
  mkdir -p "$VAULT"/{00-Inbox,01-LXS/{Persimmon\ Homes/{meetings,decisions,architecture},_new-client-template/{meetings,decisions,architecture}},02-Startups/{AdTecher/{meetings,decisions,architecture,roadmap},Ledgx/{meetings,decisions,architecture,compliance}},03-Clients/{Wayv\ Telcom/{meetings,decisions},ClubRevAI/notes},04-Knowledge/{architecture-patterns,fastapi,claude-code,sqlalchemy,devops},05-Templates,06-Personal}
  echo "✅ GODL1KE vault structure created"
else
  echo "✅ GODL1KE vault already exists"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "=================================================="
echo "🎉 GODL1KE Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Open Ghostty and source your shell:  source ~/.zshrc"
echo "  2. Install Claude Code plugins (in a Claude Code session):"
echo "     /plugin marketplace add thedotmack/claude-mem"
echo "     /plugin install claude-mem"
echo "     /plugin marketplace add obra/superpowers-marketplace"
echo "     /plugin install superpowers@superpowers-marketplace"
echo "     /plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill"
echo "     npx skills add emilkowalski/skill"
echo "  3. Configure claude-mem provider in ~/.claude-mem/settings.json"
echo "  4. Clone project repos and set up per-project CLAUDE.md files"
echo "  5. Run 'pre-commit install' in each project"
echo "  6. Update ~/.gitconfig with your actual name and email"
echo ""
