# GODL1KE Dotfiles

Aman's complete dev environment — M2 Max MacBook Pro fresh install blueprint.

## What's Inside

| Directory | Contents |
|-----------|----------|
| `zsh/` | Shell config, aliases, project switching |
| `starship/` | Prompt configuration |
| `tmux/` | Terminal multiplexer config with project sessions |
| `git/` | Git config with SSH signing, global gitignore |
| `ghostty/` | Terminal appearance and behaviour |
| `claude/` | Claude Code: CLAUDE.md, hooks, agents, slash commands |
| `claude-json/` | MCP server configuration |
| `pre-commit/` | Git pre-commit hook template |
| `raycast/` | Project switching scripts |
| `templates/` | Per-project templates (CLAUDE.md, .env.example, Obsidian) |

## Quick Start

```bash
# 1. Clone this repo
git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/.dotfiles

# 2. Run the installer
cd ~/.dotfiles
chmod +x install.sh
./install.sh

# 3. Follow the post-install steps printed at the end
```

## The Setup Philosophy

- **Hooks over instructions**: Safety guards and formatting are enforced by hooks (deterministic), not CLAUDE.md (advisory)
- **Under 200 lines**: CLAUDE.md files are kept lean — every line competes for Claude's attention
- **Symlinks over copies**: All configs are symlinked from this repo, so `git pull` updates everything
- **PR gate**: Every PR must pass lint, tests, and security checks automatically
- **Memory on autopilot**: Auto Memory + claude-mem run in the background with zero manual management
<!-- Updated: 2026-04-15 23:13:20 -->
<!-- Updated: 2026-04-15 23:13:30 -->
<!-- Updated: 2026-04-15 23:13:39 -->
<!-- Updated: 2026-04-15 23:13:49 -->
<!-- Updated: 2026-04-15 23:13:58 -->
<!-- Updated: 2026-04-15 23:14:07 -->
<!-- Updated: 2026-04-15 23:14:17 -->
<!-- Updated: 2026-04-15 23:14:27 -->
<!-- Updated: 2026-04-15 23:14:37 -->
<!-- Updated: 2026-04-15 23:14:46 -->
<!-- Updated: 2026-04-15 23:14:55 -->
<!-- Updated: 2026-04-15 23:15:04 -->
<!-- Updated: 2026-04-15 23:15:14 -->
<!-- Updated: 2026-04-15 23:15:23 -->
<!-- Updated: 2026-04-15 23:15:33 -->
