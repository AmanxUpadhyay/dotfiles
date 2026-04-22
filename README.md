# GODL1KE Dotfiles

> A fresh-Mac blueprint for an AI-assisted engineering environment: Claude Code with opinionated hooks, a second-brain pipeline into Obsidian, and enough observability to know when something's broken.

Aman's personal setup. Forkable, customisable, and documented for three kinds of reader:

- **You, six months from now** — jump to [ARCHITECTURE.md](docs/ARCHITECTURE.md) for the why-it's-shaped-like-this.
- **A stranger on GitHub wanting to replicate it** — go to [INSTALL.md](docs/INSTALL.md).
- **Someone adding a hook / command / agent** — see [CONTRIBUTING.md](docs/CONTRIBUTING.md).

---

## What this actually is

A dotfiles repo with the usual shell/git/terminal configs, plus a heavily customised Claude Code harness:

- **19 hooks** covering the full lifecycle (session start/end, prompt submit, pre/post tool use, permission grant/deny, compaction, failures). Each one is a small bash script with a `purpose / inputs / outputs / side-effects` header.
- **10 slash commands** (`/review`, `/security-scan`, `/health-check`, `/handoff-to-execute`, `/checkpoint`, `/catchup`, `/hook-health`, `/audit`, `/deploy-check`, `/test-all`).
- **2 custom subagents** (`code-reviewer`, `researcher`) with per-agent model routing and per-agent permission scopes.
- **3 live LaunchAgents** (`claude-mem-worker`, `log-rotate`, `mac-cleanup-scan`) plus 6 archived ones kept for historical reference.
- **Obsidian integration** — session notes, bug-jar entries, checkpoints, and daily retrospectives are written automatically via MCP.
- **13 bats regression suites** guarding the hook + cron contracts.

If that sounds useful, keep reading. If you just want the shell and git config, the relevant directories are `zsh/`, `git/`, `tmux/`, `starship/`, `ghostty/` — they're all standalone.

---

## Quick start (for someone who knows what they're doing)

```bash
git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
./claude/install-launchagents.sh   # optional: installs the 3 live crons
```

Then read [INSTALL.md](docs/INSTALL.md) for the customisation you'll almost certainly need to do (Obsidian vault path, org-map keywords, MCP server auth).

---

## Prerequisites

Minimum versions that have been tested on this machine (M2 Max, macOS 15+).

| Tool | Version | Why |
|---|---|---|
| macOS | 14.0+ | Some hooks use `log show` and modern `launchctl` subcommands |
| Homebrew | Any recent | Installs everything below |
| bash | 4.0+ (Homebrew) | Several hooks use `declare -A` which crashes Apple's bundled bash 3.2 |
| Node | 20+ | claude-mem plugin runs under bun/Node |
| Python | 3.11+ | `claude-stack-audit` subproject + settings.json parsing |
| jq | Any | Every hook parses/builds JSON with it |
| bats-core | 1.10+ | Test harness for all shell code |
| terminal-notifier | Any | Preferred over osascript for cron failure notifications (auto-replaces) |
| Claude Code CLI | 2.x+ | The whole pipeline runs under Claude Code |
| Obsidian | Any | Vault must be iCloud-synced for the MCP integration |

Homebrew one-liner for all required packages:

```bash
brew install bash jq bats-core terminal-notifier gh node@20
```

---

## What's inside

| Directory | Contents |
|---|---|
| `zsh/` | Shell config, aliases, project-switching helpers |
| `starship/` | Prompt configuration |
| `tmux/` | Terminal multiplexer config with project sessions |
| `git/` | Git config with SSH-signed commits, global gitignore |
| `ghostty/` | Terminal appearance + keybindings |
| `claude/` | **The main event** — CLAUDE.md, hooks, agents, commands, crons, launchagents. See [claude/README.md](claude/README.md). |
| `claude-json/` | MCP server configuration (`context7`, `sequential-thinking`, `linear`, `obsidian`) |
| `claude-stack-audit/` | Python tool that audits the hook + cron pipeline health |
| `tests/` | bats regression suites — 13 files, covers every hook and cron |
| `docs/` | Audience-facing documentation: [INSTALL](docs/INSTALL.md), [CONTRIBUTING](docs/CONTRIBUTING.md), [ARCHITECTURE](docs/ARCHITECTURE.md), [settings.hooks.md](docs/settings.hooks.md) |
| `pre-commit/` | Git pre-commit hook template |
| `raycast/` | Project switching scripts |
| `templates/` | Per-project templates (CLAUDE.md, .env.example, Obsidian setup) |

---

## Design principles

These are load-bearing — everything else follows from them. Full reasoning lives in [ARCHITECTURE.md](docs/ARCHITECTURE.md).

- **Hooks over instructions.** Safety guards, formatting, and test-on-save are enforced by hooks (deterministic), not CLAUDE.md (advisory). If it has to happen, a hook enforces it.
- **Upstream safety.** Zero modifications to plugins or Claude Code internals. Every customisation lives in this repo. Plugin auto-updates cannot break the pipeline.
- **Passive observability.** New hooks log failures; they don't modify behaviour. `/health-check` is on-demand. Nothing runs on a schedule that didn't have to.
- **Per-agent model routing.** Critical-path subagents (`code-reviewer`, `researcher`, `/review`, `/security-scan`) run Opus 4.7. Everything else stays Sonnet for cost.
- **Defense in depth on permissions.** `defaultMode: acceptEdits` + `permissions.allow` list + `permission-auto-approve.sh` hook + `safety-guards.sh` hook. Four overlapping layers.
- **Soft enforcement for LLM behaviour.** Context7 use, researcher dispatch, plan handoffs — all enforced via CLAUDE.md rules, not hard-blocking hooks. Cheaper and upstream-safe.
- **Obsidian as a second brain.** Session notes, bug fixes, architectural decisions, project context — all persisted automatically. No markdown written by hand.
- **launchd over crontab.** Every scheduled job runs as a user LaunchAgent with proper env vars, stdout/stderr capture, and per-job logs.
- **TDD on shell.** Every hook has a bats regression suite. The `pr-gate.sh` hook will reject a PR that breaks one.

---

## Key files you'll want to customise

On a fresh fork, these are the four places that need your personal info before the pipeline works:

| File | What to change |
|---|---|
| `claude/env.sh` | `OBSIDIAN_VAULT` (path to your iCloud Obsidian vault), `CLAUDE_BIN` (falls back through a resolution chain, usually unset is fine) |
| `claude/org-map.json` | CWD-keyword → org-name mapping. The pipeline routes session notes and daily retros to different vault folders based on which org a repo belongs to. |
| `claude-json/claude.json` | MCP server tokens (Linear API key, Obsidian vault path) — these are template strings in the committed file; fill in your own |
| `~/.claude/settings.json` | **Not in this repo.** Symlinked by `install.sh`. Holds your enabled plugins, allow-list, env vars. Customise after install. |

Everything else should work out of the box.

---

## Verifying the install worked

From a fresh Claude Code session in any repo:

```
/health-check
```

That runs a read-only validator across: enabled plugins, MCP server responsiveness, critical slash commands present, removed files actually removed, recent hook activity, agents loadable, permission mode, subagent model pin state. Expect 8/8 pass.

The full bats suite runs from the dotfiles root:

```bash
cd ~/.dotfiles && bats tests/
```

---

## License

Personal repo, no license — fork freely, attribute if useful. No warranties.
