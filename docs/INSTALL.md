# INSTALL — Fresh-Mac Setup Guide

This gets you from `git clone` to a working pipeline. Expect 30–60 minutes depending on what's already installed.

The repo is designed for macOS (Apple Silicon or Intel). It will not work on Linux or Windows — several hooks rely on `osascript`, `launchctl`, and macOS `log` commands.

---

## 1. Prerequisites

### 1.1 Xcode Command Line Tools

```bash
xcode-select --install
```

Click through the dialog. If it says "already installed," you're fine.

### 1.2 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the post-install instructions printed by the script to add brew to your PATH.

### 1.3 Required packages

```bash
brew install bash jq bats-core terminal-notifier gh node@20 python@3.11
```

Why each one is needed:

| Package | Purpose |
|---|---|
| `bash` (Homebrew 4+) | Several hooks use `declare -A` which crashes Apple's bash 3.2. Homebrew's `bash` is installed keg-stable so `brew upgrade bash` won't break the symlinks. |
| `jq` | Every hook parses and constructs JSON with it |
| `bats-core` | Test harness for all shell code |
| `terminal-notifier` | Preferred over `osascript` for cron-failure notifications — supports `-group` for auto-replacement |
| `gh` | GitHub CLI, required by `pr-gate.sh` |
| `node@20` | claude-mem plugin runs under Node 20 |
| `python@3.11` | `claude-stack-audit` + settings.json validation |

### 1.4 Claude Code CLI

If you don't already have it:

```bash
curl -fsSL https://install.claude.com/ | bash
```

Confirm with:

```bash
claude --version
```

Version 2.x or later is required for several hook events (`PostCompact`, `PostToolUseFailure`, `StopFailure`) referenced in `~/.claude/settings.json`.

### 1.5 Obsidian

Install Obsidian and set up an iCloud-synced vault. The exact path must be reachable from the command line — something like `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/<VaultName>`. Empty folders the pipeline expects (will be created automatically on first write if missing, but you can pre-create for clarity):

- `00-Inbox/` — cron-failure notes and misc inbox
- `04-Knowledge/Bug-Jar/` — bug-fix records
- `04-Knowledge/Hook-Health/` — daily `/hook-health` digests
- `06-Sessions/<OrgName>/` — per-session notes, one folder per org

---

## 2. Clone and bootstrap

### 2.1 Clone

```bash
git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

If you're forking and don't have an existing repo, fork on GitHub first, then clone the fork.

### 2.2 Run the installer

```bash
./install.sh
```

`install.sh` is idempotent and runs 5 phases: macOS foundation → shell/terminal → git → Python → Claude Code. Each phase checks what's already installed. Expect lots of `echo "✓ already installed"` output on second runs.

What it does to `~/.claude/`:

- Symlinks `claude/CLAUDE.md` → `~/.claude/CLAUDE.md`
- Symlinks `claude/settings.json` → `~/.claude/settings.json` (this file IS tracked in the repo; the symlink means edits to the tracked file take effect in the live runtime immediately)
- Symlinks every `claude/hooks/*.sh` into `~/.claude/hooks/` and makes them executable
- Symlinks every `claude/agents/*.md` into `~/.claude/agents/`
- Symlinks every `claude/commands/*.md` into `~/.claude/commands/`

### 2.3 Install the LaunchAgents (optional)

If you want the scheduled crons (`claude-mem-worker`, `log-rotate`, `mac-cleanup-scan`):

```bash
./claude/install-launchagents.sh
```

This symlinks the three active plists into `~/Library/LaunchAgents/` and boots them into your current `gui/<uid>` launchd domain. Verify with:

```bash
launchctl list | grep godl1ke.claude
```

You should see three entries. `mac-cleanup-scan` runs Sundays 10:00; `log-rotate` runs Sundays 11:00; `claude-mem-worker` runs on login and stays up via KeepAlive.

---

## 3. MCP server setup

The repo wires four MCP servers via `claude-json/claude.json`. Plugins add more automatically via Claude Code's marketplace system.

### 3.1 Manually-wired MCP servers

| Server | Purpose | Auth needed |
|---|---|---|
| `context7` | Fetch current docs for any library/framework/SDK | None (public endpoint) |
| `sequential-thinking` | Multi-step reasoning tool | None |
| `linear` | Linear issue tracker integration | Linear API key |
| `obsidian` | Read/write notes in your Obsidian vault | Vault path |

Edit `claude-json/claude.json` and fill in your values where you see template placeholders. Commit the edits **only if you are not publishing this fork** — the file contains secrets once edited.

### 3.2 Plugin-based MCP servers

The following plugins are enabled in `~/.claude/settings.json`'s `enabledPlugins` and auto-install their MCP servers on first session:

| Plugin | MCP server(s) it adds |
|---|---|
| `superpowers` | Core superpowers skills and the brainstorming agent |
| `superpowers-chrome` | `chrome` — browser automation via CDP |
| `episodic-memory` | `episodic-memory` — searches past conversation transcripts |
| `claude-mem` | `mcp-search` — cross-session semantic memory |
| `claude-session-driver` | Session-driver orchestration |
| `elements-of-style` | Strunk & White writing skill |
| `superpowers-developing-for-claude-code` | Plugin + hook development helpers |
| `ui-ux-pro-max` | UI/UX design intelligence |

Plugin installs happen automatically when Claude Code starts and sees them in `enabledPlugins`. No manual action needed after the first session boot.

### 3.3 claude-mem worker

The `claude-mem` plugin needs a local HTTP worker running. The LaunchAgent `com.godl1ke.claude-mem-worker.plist` starts it on login via `claude/crons/claude-mem-worker.sh`. If you skipped §2.3, kick it off manually:

```bash
bash ~/.dotfiles/claude/crons/claude-mem-worker.sh &
```

Verify the worker is responding:

```bash
curl -s "http://127.0.0.1:${CLAUDE_MEM_WORKER_PORT:-37701}/api/health"
```

Expected: JSON with `mcpReady: true`.

---

## 4. Customisation

Four files need your personal values. On a clean fork the template values won't route things to your vault correctly.

### 4.1 `claude/env.sh`

Set your Obsidian vault path:

```bash
export OBSIDIAN_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/YourVaultName"
```

Other env vars (`CLAUDE_LOG_DIR`, `ORG_MAP`, `CLAUDE_BIN`) have sensible defaults; override only if your paths differ.

### 4.2 `claude/org-map.json`

This maps CWD-path keywords to org names. Each of your work projects should have an entry. Example:

```json
{
  "orgs": {
    "AdTecher": {
      "keywords": ["adtecher", "vulcan"],
      "session_folder": "AdTecher",
      "wikilink": "[[02-Startups/AdTecher/AdTecher|AdTecher]] · [[VAULT]]"
    },
    "Personal": {
      "keywords": [],
      "session_folder": "Personal",
      "wikilink": "[[VAULT]]"
    }
  },
  "default": "Personal"
}
```

`detect-org.sh` uses longest-match-wins on the CWD path. If no keyword matches, it falls back to `default`.

### 4.3 `claude/settings.json` (tracked in this repo, symlinked as `~/.claude/settings.json`)

Unlike many dotfiles setups, this one **does** track `settings.json`. `install.sh` symlinks it to `~/.claude/settings.json`, so edits to the tracked file take effect in the live runtime immediately. The file holds hooks wiring, permission rules, enabled plugins, and env vars.

The canonical on-repo version is tuned to this machine and contains no secrets. If you need auth tokens in settings.json for your own forks, either (a) put them in a gitignored `settings.local.json` that Claude Code merges with the tracked one, or (b) keep your secrets in environment variables Claude Code resolves at runtime (`ANTHROPIC_API_KEY`, `LINEAR_API_KEY`, etc.) rather than baking them into the file.

The `hooks` block in the tracked file is the canonical wiring — you don't have to re-populate it. If you want a lighter-weight starting point for a fork, [docs/settings.hooks.md](settings.hooks.md) is the event-to-handler catalog you can cherry-pick from.

### 4.4 `claude-json/claude.json` MCP tokens

Linear needs an API key; Obsidian needs a vault path. Fill them in and don't commit the edits publicly.

---

## 5. Post-install verification

From a fresh Claude Code session (just type `claude` in any directory):

```
/health-check
```

You should see 8/8 checks pass:

1. Plugins match expected list
2. MCP servers respond
3. Critical commands exist
4. Removed files are absent
5. Recent hook activity (last 24h)
6. Agents loadable
7. Permission mode = `acceptEdits`
8. Subagent model pin absent

If any FAIL, see §6 Troubleshooting.

Next, run the bats suite:

```bash
cd ~/.dotfiles && bats tests/
```

Expect all green (typical count: 104+ tests, 0 failures). If anything fails, something is customisation-specific — look at the test name and match it to your customised config.

---

## 6. Troubleshooting

### "Claude CLI not found" errors from hooks

The claude CLI path is resolved by `env.sh` via a chain. If it fails:

```bash
source ~/.dotfiles/claude/env.sh
echo "$CLAUDE_BIN"
which claude
```

If `$CLAUDE_BIN` is empty and `which claude` works, set it manually in `env.sh`.

### "bash: declare: -A: invalid option" — hook crashes

Apple's bash 3.2 is being used. You have Homebrew bash 4+ installed but the hook isn't finding it. Two fixes:

1. Prepend Homebrew bin to your PATH in `~/.zshrc`: `export PATH="/opt/homebrew/bin:$PATH"`.
2. For LaunchAgents, the plist must specify the bash path explicitly. `com.godl1ke.claude.mac-cleanup-scan.plist` is the canonical example — it pins `/opt/homebrew/opt/bash/bin/bash`.

### `terminal-notifier: command not found` from cron failure handler

`notify-failure.sh` falls back to `osascript` when `terminal-notifier` is missing. Install it with `brew install terminal-notifier` — preferred because it supports `-group` for auto-replacement in Notification Centre.

### MCP server not responding

First, check `~/.claude/logs/` and `~/Library/Logs/claude-crons/claude-mem-worker-*.log` for recent errors.

For claude-mem specifically:

```bash
launchctl kickstart -k gui/$(id -u)/com.godl1ke.claude-mem-worker
sleep 3
curl -s "http://127.0.0.1:${CLAUDE_MEM_WORKER_PORT:-37701}/api/health"
```

For obsidian/context7/linear, check the MCP server logs that Claude Code prints on startup — usually to `~/.claude/logs/`.

### org-map keyword not matching

`detect-org.sh` prints debug info if you source it interactively:

```bash
cd /path/to/your/project
source ~/.dotfiles/claude/hooks/detect-org.sh
echo "DETECTED_ORG=$DETECTED_ORG"
```

If the output is `Personal` and you expected your org, your keyword in `org-map.json` doesn't match the path. Remember: matching is case-insensitive and uses longest-match-wins.

### bats tests fail on a fresh install

Most common causes:
- PATH order — some tests stub binaries via `$BATS_TEST_TMPDIR`. If your PATH has an unexpected entry first, stubs don't win.
- Missing dependencies — check the test file's `setup()` for what it assumes (ruff, pytest, pip-audit, etc.).
- Customisation-specific — a test assumes your `OBSIDIAN_VAULT` has a specific structure.

Run one test file at a time to isolate: `bats tests/env_preflight.bats`.

### Notifications keep firing from `notify_failure.bats`

Known issue. The test setup stubs `osascript` but not `terminal-notifier`, so running `bats tests/notify_failure.bats` leaks real notifications into Notification Centre when `terminal-notifier` is installed. Being fixed in a follow-up PR. Dismiss the notifications; they won't repeat until you run that test file again.

---

## Next

- To understand the architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- To add your own hook or command: [CONTRIBUTING.md](CONTRIBUTING.md)
- The hook event catalog: [settings.hooks.md](settings.hooks.md)
