# =============================================================================
# GODL1KE Brewfile — Aman's Complete Dev Environment
# =============================================================================
# WHY: This file lets you install every tool in one command: `brew bundle`
# Homebrew reads this file and installs everything listed. Idempotent —
# running it again skips already-installed packages.
# =============================================================================

# -----------------------------------------------------------------------------
# Core CLI Tools
# -----------------------------------------------------------------------------
brew "git"              # Version control
brew "gh"               # GitHub CLI — PR management, repo ops
brew "jq"               # JSON processing (used by Claude Code hooks)
brew "tmux"             # Terminal multiplexer — parallel sessions
brew "starship"         # Cross-shell prompt — fast, customisable
brew "pre-commit"       # Git pre-commit hook framework
brew "shellcheck"       # Shell script linter — used by claude-stack-audit
brew "bats-core"        # Bash test runner — used by tests/crons_smoke.bats
brew "curl"             # HTTP client (macOS ships an older version)
brew "wget"             # File downloads
brew "tree"             # Directory visualisation
brew "ripgrep"          # Fast recursive search (rg) — used by Claude Code
brew "fd"               # Fast file finder — better than `find`
brew "fzf"              # Fuzzy finder — Ctrl+R history search
brew "bat"              # Better `cat` with syntax highlighting
brew "eza"              # Modern `ls` replacement
brew "zoxide"           # Smart `cd` — learns your most-used directories
brew "direnv"           # Per-directory environment variables

# -----------------------------------------------------------------------------
# Python
# -----------------------------------------------------------------------------
brew "python@3.13"      # Python 3.13 — your standard version
brew "uv"               # Fast Python package manager (replaces pip + venv)
brew "ruff"             # Python formatter + linter (replaces Black + Flake8)

# -----------------------------------------------------------------------------
# Node.js & Bun (needed for Claude Code, claude-mem, MCP servers)
# -----------------------------------------------------------------------------
brew "node"             # Node.js 22+ — required for Claude Code npm tools
tap "oven-sh/bun"
brew "oven-sh/bun/bun"  # Bun runtime — required for claude-mem

# -----------------------------------------------------------------------------
# Cloud CLIs
# -----------------------------------------------------------------------------
brew "awscli"           # AWS CLI v2
brew "azure-cli"        # Azure CLI

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------
brew "postgresql@16"    # PostgreSQL client tools (psql, pg_dump)
# Note: PostgreSQL SERVER runs in Docker via OrbStack, not locally

# -----------------------------------------------------------------------------
# Applications
# -----------------------------------------------------------------------------
cask "ghostty"          # Terminal — GPU-accelerated, fast
cask "claude"           # Claude Desktop
cask "cursor"           # Cursor editor — PR reviews + code search
cask "raycast"          # Launcher — window management + project switching
cask "alt-tab"          # Windows-style Alt+Tab for macOS
cask "tableplus"        # Database GUI
cask "orbstack"         # Docker runtime — lighter than Docker Desktop
cask "obsidian"         # Knowledge management — GODL1KE vault
cask "adguard"          # Ad blocker
cask "tg-pro"           # System monitoring (temperature, fans)
cask "google-chrome"    # Chrome — dev tools only (Safari is primary)

# -----------------------------------------------------------------------------
# Fonts (for terminal + editor)
# -----------------------------------------------------------------------------
cask "font-jetbrains-mono-nerd-font"  # Nerd Font — icons in terminal + Starship
