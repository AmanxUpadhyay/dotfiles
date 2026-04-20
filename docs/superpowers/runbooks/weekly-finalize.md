# Runbook: weekly-finalize

## What this is

Monday morning job that finalizes last week's draft reports. It updates the report period status from `friday-draft` to `final` and adds a Week Start Focus section, closing out the weekly review cycle.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude.weekly-finalize` (archived plist) |
| Crontab.txt | `3 9 * * 1` — 9:03 AM every Monday |
| Crontab status | DEPRECATED — crontab.txt is retired in favour of launchd |

> **Note:** Plist lives in `launchagents/archived/`. To re-enable: move out of `archived/` and run `install-launchagents.sh`.

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Fires at 9:03 AM every Monday to update last week's period from `friday-draft` to `final` and add a Week Start Focus section |
| Inputs | `CLAUDE_BIN`, `CLAUDE_LOG_DIR`, `OBSIDIAN_VAULT` from `env.sh`; prompt from `claude/prompts/weekly-finalize.md`; optional `DATE_HINT` env override |
| Outputs | Weekly report notes updated in Obsidian vault |
| Side-effects | Invokes claude CLI with `--dangerously-skip-permissions`; calls `notify_failure` on failure; touches `.last-success-weekly-finalize` on success |

## Failure modes

1. **`weekly-report-gen` did not run Friday** — there are no draft reports to finalize. Claude will likely report nothing to update. Not a script failure, but a missing upstream. Fix: run `weekly-report-gen.sh` manually first with a `DATE_HINT` pointing to last Friday.
2. **Obsidian vault not mounted** — `preflight_check` fails. Fix: wait for iCloud sync, then re-run manually.
3. **`CLAUDE_BIN` stale** — `preflight_check` fails. Fix: `source ~/.claude/env.sh && echo $CLAUDE_BIN`.
4. **Prompt file missing** (`claude/prompts/weekly-finalize.md`) — script exits 1. Fix: restore from git.
5. **Claude CLI exits non-zero** — `notify_failure` fires; output logged. Fix: inspect the log for the specific Claude error.

## Recovery steps

```bash
# Re-run for this Monday
bash ~/.dotfiles/claude/crons/weekly-finalize.sh

# Back-fill with a specific date hint
DATE_HINT="Today is 2026-04-14 (Monday)." bash ~/.dotfiles/claude/crons/weekly-finalize.sh

# Check the log
tail -50 ~/Library/Logs/claude-crons/weekly-final-$(date +%Y-%m-%d).log

# Verify preflight
source ~/.claude/env.sh && echo "CLAUDE_BIN=$CLAUDE_BIN"

# Check last-success marker
ls -la ~/Library/Logs/claude-crons/.last-success-weekly-finalize

cstack-audit run
```

## Related

- Script: `~/.dotfiles/claude/crons/weekly-finalize.sh`
- Prompt: `~/.dotfiles/claude/prompts/weekly-finalize.md`
- Upstream: `weekly-report-gen` (Friday 5:02 PM — must succeed for drafts to exist)
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Log: `~/Library/Logs/claude-crons/weekly-final-YYYY-MM-DD.log`
