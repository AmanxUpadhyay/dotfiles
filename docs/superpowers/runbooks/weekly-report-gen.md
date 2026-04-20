# Runbook: weekly-report-gen

## What this is

Friday afternoon job that generates per-org weekly reports and a combined weekly summary from Monday–Friday daily notes. Its output is the raw material `weekly-finalize` polishes on Monday morning.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude.weekly-report-gen` (archived plist) |
| Crontab.txt | `2 17 * * 5` — 5:02 PM every Friday |
| Crontab status | DEPRECATED — crontab.txt is retired in favour of launchd |

> **Note:** Plist lives in `launchagents/archived/`. To re-enable: move out of `archived/` and run `install-launchagents.sh`.

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Fires at 5:02 PM every Friday to generate per-org weekly reports and a combined summary from Mon–Fri daily notes |
| Inputs | `CLAUDE_BIN`, `CLAUDE_LOG_DIR`, `OBSIDIAN_VAULT` from `env.sh`; prompt from `claude/prompts/weekly-report-gen.md`; optional `DATE_HINT` env override |
| Outputs | Per-org report notes + `07-Daily/YYYY-WNN-weekly-summary.md` written to Obsidian vault |
| Side-effects | Invokes claude CLI with `--dangerously-skip-permissions`; calls `notify_failure` on failure; touches `.last-success-weekly-report-gen` on success |

Per-org reports are written to the org's `reports/weekly/` subdirectory as referenced in `healthcheck.sh`'s vault structure checks (e.g. `01-LXS/reports/weekly/`, `02-Startups/AdTecher/reports/weekly/`).

## Failure modes

1. **Daily notes missing for the week** — Claude has no source material. It will likely write a sparse or empty report. Not a script error. Fix: back-fill missing daily notes with `daily-retrospective.sh` using `DATE_HINT` overrides, then re-run this script.
2. **Obsidian vault not mounted** — `preflight_check` fails. Fix: wait for iCloud sync, then re-run manually.
3. **`CLAUDE_BIN` stale** — `preflight_check` fails. Fix: `source ~/.claude/env.sh && echo $CLAUDE_BIN`.
4. **Prompt file missing** (`claude/prompts/weekly-report-gen.md`) — script exits 1. Fix: restore from git.
5. **Claude CLI exits non-zero** — `notify_failure` fires; output logged. Fix: inspect the log.

## Recovery steps

```bash
# Re-run for this Friday
bash ~/.dotfiles/claude/crons/weekly-report-gen.sh

# Back-fill a missed Friday
DATE_HINT="Today is 2026-04-11 (Friday)." bash ~/.dotfiles/claude/crons/weekly-report-gen.sh

# Check the log
tail -50 ~/Library/Logs/claude-crons/weekly-gen-$(date +%Y-%m-%d).log

# Verify preflight
source ~/.claude/env.sh && echo "CLAUDE_BIN=$CLAUDE_BIN"

# Check last-success marker
ls -la ~/Library/Logs/claude-crons/.last-success-weekly-report-gen

cstack-audit run
```

## Related

- Script: `~/.dotfiles/claude/crons/weekly-report-gen.sh`
- Prompt: `~/.dotfiles/claude/prompts/weekly-report-gen.md`
- Upstream: `daily-retrospective` (Mon–Fri daily notes feed this script)
- Downstream: `weekly-finalize` (Monday 9:03 AM — consumes this script's draft reports)
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Log: `~/Library/Logs/claude-crons/weekly-gen-YYYY-MM-DD.log`
