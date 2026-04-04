# =============================================================================
# GODL1KE .zshrc — Aman's Shell Configuration
# =============================================================================
# WHY: This is your shell's brain. It sets up PATH, aliases, completions,
# and project-switching shortcuts so you can jump between six projects
# instantly. Sourced every time you open a terminal.
# =============================================================================

# -----------------------------------------------------------------------------
# PATH Configuration
# -----------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"  # fallback for non-login shells
export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
typeset -U PATH  # deduplicate PATH entries (zsh built-in)

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
export EDITOR="cursor --wait"
export VISUAL="cursor --wait"
export LANG="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"

# Python — ensure uv is the default
export UV_PYTHON_PREFERENCE="only-managed"

# -----------------------------------------------------------------------------
# Shell Options
# -----------------------------------------------------------------------------
setopt AUTO_CD              # cd into directories by typing the name
setopt CORRECT              # Suggest corrections for typos
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_ALL_DUPS # No duplicate history entries
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history

# -----------------------------------------------------------------------------
# Completions
# -----------------------------------------------------------------------------
autoload -Uz compinit && compinit
eval "$(gh completion -s zsh)"

# -----------------------------------------------------------------------------
# Tool Initialisations
# -----------------------------------------------------------------------------
eval "$(starship init zsh)"         # Starship prompt
eval "$(zoxide init zsh)"           # Smart cd (use `z` instead of `cd`)
eval "$(fzf --zsh)"                 # Fuzzy finder keybindings (Ctrl+R)
eval "$(direnv hook zsh)"           # Per-directory env vars

# -----------------------------------------------------------------------------
# Aliases — General
# -----------------------------------------------------------------------------
alias ls="eza --icons"
alias ll="eza --icons -la"
alias lt="eza --icons --tree --level=2"
alias cat="bat --paging=never"
alias grep="rg"
alias find="fd"

# Git shortcuts
alias gs="git status"
alias gd="git diff"
alias gl="git log --oneline -20"
alias gp="git pull"
alias gc="git commit"
alias gco="git checkout"
alias gb="git branch"
alias gpr="gh pr create --fill"

# Python
alias py="python3"
alias act="source .venv/bin/activate"

# Docker
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"

# Claude Code
alias cc="claude"
alias ccw="claude --worktree"
alias ccp="claude -p"

# -----------------------------------------------------------------------------
# Project Switching — tmux sessions
# -----------------------------------------------------------------------------
# WHY: Each project gets a named tmux session. `px` jumps to it instantly.
# If the session doesn't exist, it creates one in the right directory.

# Update these paths after cloning your repos
export DIR_LXS="$HOME/projects/lxs"
export DIR_PERSIMMON="$HOME/projects/persimmon-homes"
export DIR_ADTECHER="$HOME/projects/adtecher"
export DIR_WAYV="$HOME/projects/wayv"
export DIR_CLUBREVAI="$HOME/projects/clubrevai"
export DIR_LEDGX="$HOME/projects/ledgx"

# Project switch function
px() {
  local session_name=$1
  local project_dir=$2

  if [ -z "$session_name" ] || [ -z "$project_dir" ]; then
    echo "Usage: px <session-name> <project-dir>"
    return 1
  fi

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -c "$project_dir"
  fi
  tmux switch-client -t "$session_name" 2>/dev/null || tmux attach-session -t "$session_name"
}

# Quick project aliases
alias plxs="px lxs $DIR_LXS"
alias pper="px persimmon $DIR_PERSIMMON"
alias padt="px adtecher $DIR_ADTECHER"
alias pwav="px wayv $DIR_WAYV"
alias pclub="px clubrevai $DIR_CLUBREVAI"
alias pledg="px ledgx $DIR_LEDGX"

# List all project sessions
alias pls="tmux list-sessions 2>/dev/null || echo 'No active sessions'"

# -----------------------------------------------------------------------------
# Claude Code Worktree Helpers
# -----------------------------------------------------------------------------
# WHY: Quick parallel worktree creation within the current project
ccf() {
  # Usage: ccf feature-name
  # Creates a worktree and starts Claude in it
  claude --worktree "$1"
}

# -----------------------------------------------------------------------------
# Quick Functions
# -----------------------------------------------------------------------------
# Create a new FastAPI project with standard structure
mkfastapi() {
  local name=$1
  mkdir -p "$name"/{app/{api,services,repositories,models,schemas},tests}
  touch "$name"/app/__init__.py
  touch "$name"/app/api/__init__.py
  touch "$name"/app/services/__init__.py
  touch "$name"/app/repositories/__init__.py
  touch "$name"/app/models/__init__.py
  touch "$name"/app/schemas/__init__.py
  touch "$name"/tests/__init__.py
  echo "Created FastAPI structure in $name/"
}

alias claude-mem='bun "/Users/godl1ke/.claude/plugins/cache/thedotmack/claude-mem/10.6.3/scripts/worker-service.cjs"'


# -----------------------------------------------------------------------------
# Claude Code — additions April 2026 (v2.1.91+)
# -----------------------------------------------------------------------------
export CLAUDE_CODE_NO_FLICKER="1"

# Secrets — fill these in
export CONTEXT7_API_KEY=""  # https://context7.com/dashboard — free key raises rate limit from 1k/month
export SENTRY_ORG="aman-h2"        # your Sentry org slug

# Parallel worktree launcher — usage: cc_parallel "feat-auth" "fix-payments" "refactor-api"
cc_parallel() {
  local PROJECT_DIR="${PWD}"
  for name in "$@"; do
    tmux new-session -d -s "$name" -c "$PROJECT_DIR" "claude --worktree $name" 2>/dev/null || \
      tmux new-window -t "$name" -c "$PROJECT_DIR" "claude --worktree $name"
    echo "Started: $name"
  done
  echo "Attach: tmux attach -t <name>"
}
