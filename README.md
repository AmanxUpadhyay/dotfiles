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
<!-- Updated: 2026-04-15 23:15:44 -->
<!-- Updated: 2026-04-15 23:15:53 -->
<!-- Updated: 2026-04-15 23:16:03 -->
<!-- Updated: 2026-04-15 23:16:12 -->
<!-- Updated: 2026-04-15 23:16:22 -->
<!-- Updated: 2026-04-15 23:16:32 -->
<!-- Updated: 2026-04-15 23:16:41 -->
<!-- Updated: 2026-04-15 23:16:50 -->
<!-- Updated: 2026-04-15 23:17:00 -->
<!-- Updated: 2026-04-15 23:17:10 -->
<!-- Updated: 2026-04-15 23:17:19 -->
<!-- Updated: 2026-04-15 23:17:28 -->
<!-- Updated: 2026-04-15 23:17:38 -->
<!-- Updated: 2026-04-15 23:17:47 -->
<!-- Updated: 2026-04-15 23:17:57 -->
<!-- Updated: 2026-04-15 23:18:07 -->
<!-- Updated: 2026-04-15 23:18:17 -->
<!-- Updated: 2026-04-15 23:18:27 -->
<!-- Updated: 2026-04-15 23:18:36 -->
<!-- Updated: 2026-04-15 23:18:46 -->
<!-- Updated: 2026-04-15 23:18:55 -->
<!-- Updated: 2026-04-15 23:19:05 -->
<!-- Updated: 2026-04-15 23:19:14 -->
<!-- Updated: 2026-04-15 23:19:24 -->
<!-- Updated: 2026-04-15 23:19:33 -->
<!-- Updated: 2026-04-15 23:19:42 -->
<!-- Updated: 2026-04-15 23:19:51 -->
<!-- Updated: 2026-04-15 23:20:01 -->
<!-- Updated: 2026-04-15 23:20:12 -->
<!-- Updated: 2026-04-15 23:20:21 -->
<!-- Updated: 2026-04-15 23:20:30 -->
<!-- Updated: 2026-04-15 23:20:40 -->
<!-- Updated: 2026-04-15 23:20:49 -->
<!-- Updated: 2026-04-15 23:20:58 -->
<!-- Updated: 2026-04-15 23:21:08 -->
<!-- Updated: 2026-04-15 23:21:18 -->
<!-- Updated: 2026-04-15 23:21:27 -->
<!-- Updated: 2026-04-16 16:09:33 -->
<!-- Updated: 2026-04-16 16:09:57 -->
<!-- Updated: 2026-04-16 16:10:21 -->
<!-- Updated: 2026-04-16 16:10:45 -->
<!-- Updated: 2026-04-16 16:11:09 -->
<!-- Updated: 2026-04-16 16:11:33 -->
<!-- Updated: 2026-04-16 16:11:57 -->
<!-- Updated: 2026-04-16 16:12:21 -->
<!-- Updated: 2026-04-16 16:12:45 -->
<!-- Updated: 2026-04-16 16:13:09 -->
<!-- Updated: 2026-04-16 16:13:32 -->
<!-- Updated: 2026-04-16 16:13:56 -->
<!-- Updated: 2026-04-16 16:14:19 -->
<!-- Updated: 2026-04-16 16:14:42 -->
<!-- Updated: 2026-04-16 16:15:06 -->
<!-- Updated: 2026-04-16 16:15:30 -->
<!-- Updated: 2026-04-16 16:15:54 -->
<!-- Updated: 2026-04-16 16:16:18 -->
<!-- Updated: 2026-04-16 16:16:43 -->
<!-- Updated: 2026-04-16 16:17:06 -->
<!-- Updated: 2026-04-16 16:17:30 -->
<!-- Updated: 2026-04-16 16:17:55 -->
<!-- Updated: 2026-04-16 16:18:19 -->
<!-- Updated: 2026-04-16 16:18:43 -->
<!-- Updated: 2026-04-16 16:19:06 -->
<!-- Updated: 2026-04-16 16:19:29 -->
<!-- Updated: 2026-04-16 16:19:53 -->
<!-- Updated: 2026-04-16 16:20:16 -->
<!-- Updated: 2026-04-16 16:20:40 -->
<!-- Updated: 2026-04-16 16:21:03 -->
