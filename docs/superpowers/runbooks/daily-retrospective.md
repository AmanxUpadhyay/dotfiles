# Runbook: daily-retrospective

## What this is

Morning cron that writes yesterday's daily note into the Obsidian vault at 8:57 AM. On Saturdays it captures Friday's work. It is the primary daily note producer; `daily-retro-evening` is the patch-up run.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude.daily-retrospective` (archived plist) |
| Crontab.txt | `57 8 * * *` — 8:57 AM every day |
| Crontab status | DEPRECATED — crontab.txt is retired in favour of launchd |

> **Note:** The plist lives in `launchagents/archived/`. To re-enable: move the plist out of `archived/` and run `install-launchagents.sh`. The healthcheck-preflight fires 7 minutes earlier (8:50 AM) to validate the environment before this script runs.

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Fires at 8:57 AM every day to write yesterday's daily note; Saturday captures Friday's work |
| Inputs | `CLAUDE_BIN`, `CLAUDE_LOG_DIR`, `OBSIDIAN_VAULT` from `env.sh`; prompt from `claude/prompts/daily-retrospective.md`; optional `DATE_HINT` env override |
| Outputs | `07-Daily/YYYY-MM-DD.md` created in Obsidian vault |
| Side-effects | Invokes claude CLI with `--dangerously-skip-permissions`; calls `notify_failure` on failure; touches `.last-success-daily-retrospective` on success |

The `DATE_HINT` env override allows manual back-fills: set `DATE_HINT="Today is 2026-04-14 (Tuesday)."` before running to generate a specific date's note.

## Failure modes

1. **Obsidian vault not mounted** — `preflight_check` fails, `notify_failure` fires, script exits 1. Fix: wait for iCloud sync then re-run manually with optional `DATE_HINT`.
2. **`CLAUDE_BIN` stale after CLI update** — `preflight_check` fails. Fix: `source ~/.claude/env.sh && echo $CLAUDE_BIN`. See `feedback_cron_debugging.md` memory note for history of this issue.
3. **Prompt file missing** — exits 1 after logging the error. Fix: restore from git.
4. **Claude CLI exits non-zero** — output is logged; `notify_failure` fires a macOS notification and appends an error note to `00-Inbox/YYYY-MM-DD-cron-error.md`. Fix: inspect the log.
5. **Note already exists** — Claude will typically overwrite or merge; no explicit guard. Use the evening run if you want patch-mode semantics.

## Recovery steps

```bash
# Re-run for today (generates yesterday's note)
bash ~/.dotfiles/claude/crons/daily-retrospective.sh

# Back-fill a specific date
DATE_HINT="Today is 2026-04-14 (Tuesday)." bash ~/.dotfiles/claude/crons/daily-retrospective.sh

# Check the log
tail -50 ~/Library/Logs/claude-crons/daily-retro-$(date +%Y-%m-%d).log

# Verify preflight
source ~/.claude/env.sh && echo "CLAUDE_BIN=$CLAUDE_BIN" && ls "$OBSIDIAN_VAULT/07-Daily/"

# Check last-success marker
ls -la ~/Library/Logs/claude-crons/.last-success-daily-retrospective

cstack-audit run
```

## Related

- Script: `~/.dotfiles/claude/crons/daily-retrospective.sh`
- Prompt: `~/.dotfiles/claude/prompts/daily-retrospective.md`
- Downstream: `daily-retro-evening` (patch run at 10:30 PM); `healthcheck postrun` (verifies output at 11:00 AM)
- Upstream: `healthcheck preflight` (validates env at 8:50 AM)
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Log: `~/Library/Logs/claude-crons/daily-retro-YYYY-MM-DD.log`
