# Runbook: claude-mem-worker

## What this is

Long-running background service that powers the claude-mem persistent memory plugin. It runs at login and stays alive via launchd's `KeepAlive` — it is a daemon, not a scheduled cron.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude-mem-worker` |
| Fire condition | `RunAtLoad: true` + `KeepAlive: true` — starts at login, restarts within 10 s if it exits |
| Crontab.txt | Not listed (launchd-only; crontab.txt is retired) |

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Resolve and launch the active claude-mem `worker-service.cjs` via bun |
| Inputs | None — reads `CLAUDE_LOG_DIR` from `env.sh`; plugin paths are hardcoded |
| Outputs | None at the script level — `exec bun …` replaces the process; touches `.last-success-claude-mem-worker` on clean exit |
| Side-effects | Starts a long-running bun process on port 37777 (HTTP health endpoint); sources `notify-failure.sh` |

## Failure modes

1. **`bun` not found at `/opt/homebrew/bin/bun`** — script exits 1, launchd restarts it every 10 s. Fix: `brew install bun` or correct the hardcoded path.
2. **`worker-service.cjs` missing** — both the active install path and the plugin cache are empty. Script prints an error and exits 1. Fix: reinstall the claude-mem plugin inside a Claude Code session (`/plugin install claude-mem`).
3. **Port conflict on 37777** — bun starts but the health endpoint returns nothing. Another process has taken the port. Fix: `lsof -ti:37777 | xargs kill` then re-kickstart.
4. **Plugin cache corrupted** — `ls … | sort -V | tail -1` returns an empty string. The fallback path check fails and the script exits 1. Fix: clear `~/.claude/plugins/cache/thedotmack/claude-mem/` and reinstall.

## Recovery steps

```bash
# Check current state
launchctl print gui/$(id -u)/com.godl1ke.claude-mem-worker

# Check health endpoint
curl -s http://127.0.0.1:37777/api/health

# Force restart via launchd
launchctl kickstart -k gui/$(id -u)/com.godl1ke.claude-mem-worker

# Check stdout log
tail -f ~/Library/Logs/claude-mem-worker.log
tail -f ~/Library/Logs/claude-mem-worker-error.log

# Manual one-shot run for debugging
bash ~/.dotfiles/claude/crons/claude-mem-worker.sh

# Reinstall launchagent
bash ~/.dotfiles/claude/install-launchagents.sh
```

Check `.last-success-claude-mem-worker` in `$CLAUDE_LOG_DIR` (`~/Library/Logs/claude-crons/`) to see when bun last started cleanly.

## Related

- Script: `~/.dotfiles/claude/crons/claude-mem-worker.sh`
- LaunchAgent plist: `~/.dotfiles/claude/launchagents/com.godl1ke.claude-mem-worker.plist`
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Health endpoint: `http://127.0.0.1:37777/api/health`
