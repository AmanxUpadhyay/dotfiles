# Runbook: log-rotate

## What this is

Weekly maintenance cron that prunes log files older than 30 days from `~/Library/Logs/claude-crons/`. Prevents unbounded disk growth from daily and weekly automation logs.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude.log-rotate` |
| Schedule | Sunday 11:00 AM (1 hour after mac-cleanup-scan at 10:00 AM) |

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Deletes `*.log` files in `$CLAUDE_LOG_DIR` that are older than 30 days |
| Inputs | `CLAUDE_LOG_DIR` from `env.sh` (default: `~/Library/Logs/claude-crons/`) |
| Outputs | Deletion count appended to `$CLAUDE_LOG_DIR/log-rotate.log`; `duration_ms` status marker |
| Side-effects | Removes old `.log` files; touches `.last-success-log-rotate` on success; calls `notify_failure` on ERR |

Only top-level `*.log` files are deleted (`-maxdepth 1`). Subdirectories and non-`.log` files are untouched.

## Failure modes

1. **`CLAUDE_LOG_DIR` not writable** — `find -delete` will fail, ERR trap fires, `notify_failure` sends macOS notification. Fix: check permissions on `~/Library/Logs/claude-crons/`.
2. **`env.sh` missing** — script exits at `source` with an error. Fix: verify `~/.claude/env.sh` exists.
3. **`notify-failure.sh` missing** — script exits at `source`. Fix: restore from git.

## Recovery steps

```bash
# Run manually
bash ~/.dotfiles/claude/crons/log-rotate.sh

# Check the log
tail -20 ~/Library/Logs/claude-crons/log-rotate.log

# Check last-success marker
ls -la ~/Library/Logs/claude-crons/.last-success-log-rotate

# Verify the LaunchAgent is loaded
launchctl list | grep log-rotate

# Load the LaunchAgent if not already loaded
launchctl load ~/Library/LaunchAgents/com.godl1ke.claude.log-rotate.plist
```

## Related

- Script: `~/.dotfiles/claude/crons/log-rotate.sh`
- Plist: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.log-rotate.plist`
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Log: `~/Library/Logs/claude-crons/log-rotate.log`
- Runs after: `mac-cleanup-scan` (10:00 AM Sunday)
