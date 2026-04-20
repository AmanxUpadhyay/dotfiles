# claude/

This directory contains everything that drives Claude Code automation on this machine: hooks, scheduled cron scripts, agent definitions, slash commands, prompt templates, and launchd plists.

---

## Install flow

**Fresh Mac setup:**

```bash
# Step 1 — master install (run from dotfiles root)
bash ~/.dotfiles/install.sh
```

`install.sh` handles:
- Symlinking `claude/CLAUDE.md` → `~/.claude/CLAUDE.md`
- Symlinking `claude/settings.json` → `~/.claude/settings.json`
- Symlinking every `claude/hooks/*.sh` into `~/.claude/hooks/` and making them executable
- Symlinking every `claude/agents/*.md` into `~/.claude/agents/`
- Symlinking every `claude/commands/*.md` into `~/.claude/commands/`

**Launchd agents (cron replacements):**

```bash
# Step 2 — install scheduled jobs as launchd user agents
bash ~/.dotfiles/claude/install-launchagents.sh
```

`install-launchagents.sh` symlinks `claude/launchagents/com.godl1ke.claude.*.plist` into `~/Library/LaunchAgents/` and boots them into the current `gui/<uid>` launchd domain. Run with `--uninstall` to remove all agents.

Verify with:
```bash
launchctl print gui/$(id -u) | grep godl1ke.claude
```

**After changes to a hook or cron:**
```bash
# Reload shell + re-verify everything
source ~/.dotfiles/claude/refresh.sh
```

---

## Component map

| Path | What it is |
|---|---|
| `env.sh` | Single source of truth for `PATH`, `CLAUDE_BIN`, `OBSIDIAN_VAULT`, `CLAUDE_LOG_DIR`, `ORG_MAP`. Every hook and cron sources this first. |
| `settings.json` | Claude Code global settings — hooks wiring, permission rules, enabled plugins, env vars. Symlinked to `~/.claude/settings.json`. |
| `refresh.sh` | Sourced (not executed) to reload shell, re-verify Claude binary, fix hook permissions, check MCP servers and claude-mem worker. |
| `org-map.json` | JSON map of path keywords → org names, vault folders, and wikilinks. Used by `detect-org.sh` with longest-match-wins logic. |
| `crontab.txt` | **Retired reference only.** Migrated to launchd on 2026-04-07. Do not re-install this crontab. |
| `CLAUDE.md` | Global preferences injected into every Claude Code session. Symlinked to `~/.claude/CLAUDE.md`. |
| `hooks/` | Hook scripts wired to Claude Code lifecycle events via `settings.json`. |
| `crons/` | Scheduled automation scripts + the `notify-failure.sh` library. |
| `agents/` | Sub-agent definitions (`.md` files) for specialized tasks. |
| `commands/` | Slash command definitions (`.md` files). |
| `launchagents/` | launchd plist files for active scheduled jobs. `archived/` contains jobs that migrated away. |
| `prompts/` | Prompt templates consumed by cron scripts via `cat`. |
| `docs/` | Runbooks, specs, and ADRs for this automation stack. |

---

## Hooks inventory

All hooks live in `claude/hooks/` and are symlinked to `~/.claude/hooks/`. The event mappings come from `settings.json`.

| Script | Event | Matcher | Purpose |
|---|---|---|---|
| `session-start.sh` | `SessionStart` | `startup` | Injects git context, org detection, recent Obsidian session note, org context file, and repo breadcrumbs as `additionalContext` |
| `safety-guards.sh` | `PreToolUse` | `Bash` | Blocks destructive Bash commands (rm -rf critical dirs, force push to main, hard reset, destructive SQL, curl-pipe-to-shell, fork bombs) via exit 2 |
| `pr-gate.sh` | `PreToolUse` | `Bash` | Hard gate before `gh pr` and `git push`: runs ruff format, ruff lint, pytest/npm test, secrets scan, and pip-audit |
| `protect-files.sh` | `PreToolUse` | `Write\|Edit\|MultiEdit` | Blocks writes to credential files, SSH/AWS configs, `.env` files, `.pem`/`.key`/`.p12` material |
| `auto-format.sh` | `PostToolUse` | `Write\|Edit\|MultiEdit` | Runs `ruff format` + `ruff check --fix` on every `.py` file Claude edits |
| `auto-test.sh` | `PostToolUse` | `Write\|Edit\|MultiEdit` | Finds and runs the related test file for any Python file Claude edits; feeds failures back as `additionalContext` |
| `test-fix-detector.sh` | `PostToolUse` | `Write\|Edit\|MultiEdit` | Detects test/spec file edits and reminds Claude to write a Bug Jar entry |
| `prompt-injection-guard.sh` | `UserPromptSubmit` | (all) | Scans user prompts against known injection patterns and blocks via exit 2 |
| `permission-auto-approve.sh` | `PermissionRequest` | (all) | Auto-approves `Read`, `Glob`, `Grep`, and safe read-only Bash commands without showing a dialog |
| `permission-denied.sh` | `PermissionDenied` | (all) | Logs all denials to `~/.claude/logs/permission-denied.log`; retries safe read-only operations |
| `stop-notification.sh` | `Stop` | (all) | Fires a macOS notification with Glass sound when Claude completes a non-trivial task |
| `session-stop.sh` | `Stop` | (all) | Blocks Claude from finishing until it writes a session summary note to Obsidian (skips trivial sessions and automated sessions) |
| `breadcrumb-writer.sh` | `SessionEnd` | (all) | Writes `.claude/breadcrumbs.md` into the project repo so the next session can locate relevant vault notes |
| `session-end-note.sh` | `SessionEnd` | (all) | Additional session-end note handler |
| `detect-org.sh` | (library) | — | Sourced by other hooks; maps CWD to org name, vault folder, and wikilink via `org-map.json` |

> `detect-org.sh` is a sourced library, not directly wired in `settings.json`. It is invoked by `session-start.sh`, `session-stop.sh`, `breadcrumb-writer.sh`, and `test-fix-detector.sh`.

---

## Crons inventory

Scheduled automation scripts live in `claude/crons/`. All are managed by launchd (not crontab). `crontab.txt` is kept for reference only.

| Script | Schedule | Status | Purpose |
|---|---|---|---|
| `healthcheck.sh preflight` | Daily 8:50 AM | Active (launchd) | Validates env, binary, vault dirs, and prompt templates before the morning retro fires |
| `daily-retrospective.sh` | Daily 8:57 AM | Archived plist | Generates yesterday's daily note in Obsidian using the Claude CLI |
| `healthcheck.sh postrun` | Daily 11:00 AM | Active (launchd) | Verifies yesterday's daily note exists in the vault after the morning retro |
| `daily-retro-evening.sh` | Daily 10:30 PM | Archived plist | Patches or creates today's daily note to catch sessions created after the morning run |
| `weekly-report-gen.sh` | Friday 5:02 PM | Archived plist | Generates per-org weekly reports and a combined weekly summary from Mon–Fri daily notes |
| `weekly-finalize.sh` | Monday 9:03 AM | Archived plist | Finalizes last week's draft reports: sets status to `final`, adds Week Start Focus |
| `mac-cleanup-scan.sh` | Sunday 10:00 AM | Active (launchd) | Scans disk cleanup targets; writes an Obsidian report if recoverable space >= 1 GB |
| `claude-mem-worker.sh` | At login + KeepAlive | Active (launchd) | Resolves and launches the claude-mem `worker-service.cjs` via bun; keeps the memory service running |
| `notify-failure.sh` | (library) | — | Shared library; provides `notify_failure()` for macOS notifications and Obsidian error notes |

"Archived plist" means the job definition exists in `launchagents/archived/` and is not currently active in launchd. Move the plist out of `archived/` and re-run `install-launchagents.sh` to activate.

Logs: `~/Library/Logs/claude-crons/` (`$CLAUDE_LOG_DIR`)

---

## Common troubleshooting

**Hook failing silently — no output, no error:**
```bash
tail -f ~/Library/Logs/claude-crons/<hook-name>.log
# Or check Claude Code's hook output in the session
```

**`claude` binary not found by crons/hooks:**
```bash
source ~/.claude/env.sh && echo $CLAUDE_BIN
# Expected: ~/.local/bin/claude (or npm-packages path)
# If empty: reinstall Claude Code, or set CLAUDE_BIN manually in env.sh
```

**LaunchAgent not firing:**
```bash
# Check it's loaded
launchctl print gui/$(id -u) | grep godl1ke.claude

# Kick it manually
launchctl kickstart gui/$(id -u)/com.godl1ke.claude.healthcheck-preflight

# Check launchd stdout/stderr
tail ~/Library/Logs/claude-crons/healthcheck-preflight-launchd.log
tail ~/Library/Logs/claude-crons/healthcheck-preflight-launchd-err.log
```

**Cron ran but produced no Obsidian note:**
```bash
# Check the cron log for errors
tail -50 ~/Library/Logs/claude-crons/daily-retro-$(date +%Y-%m-%d).log

# Check the Obsidian inbox for a failure note
ls "$OBSIDIAN_VAULT/00-Inbox/"*cron-error.md
```

**Overall stack health:**
```bash
cstack-audit run
# Reports check_id violations, last-success markers, score
```

**claude-mem worker not running:**
```bash
curl -s http://127.0.0.1:37777/api/health
# If no response:
launchctl kickstart -k gui/$(id -u)/com.godl1ke.claude-mem-worker
tail ~/Library/Logs/claude-mem-worker.log
```
