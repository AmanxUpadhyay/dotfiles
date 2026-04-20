# Runbook: daily-retro-evening

## What this is

Evening counterpart to `daily-retrospective`. Fires at 10:30 PM to catch sessions created after the morning run — either patching today's existing daily note or creating it fresh if it was skipped.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude.daily-retro-evening` (archived plist — migrate to active if re-enabling) |
| Crontab.txt | `30 22 * * *` — 10:30 PM every day |
| Crontab status | DEPRECATED — crontab.txt is retired in favour of launchd |

> **Note:** The plist lives in `launchagents/archived/`. This job is not currently active in launchd. To re-enable: move the plist out of `archived/` and run `install-launchagents.sh`.

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Runs at 10:30 PM to catch sessions created after the morning run; patches or creates today's daily note |
| Inputs | `CLAUDE_BIN`, `CLAUDE_LOG_DIR`, `OBSIDIAN_VAULT` from `env.sh`; prompt from `claude/prompts/daily-retrospective.md` |
| Outputs | `07-Daily/YYYY-MM-DD-dayname.md` created or patched in Obsidian vault |
| Side-effects | Invokes claude CLI with `--dangerously-skip-permissions`; calls `notify_failure` on failure; touches `.last-success-daily-retro-evening` on success |

The script injects a `DATE_HINT` that explicitly targets TODAY (not yesterday) and instructs Claude to check for an existing note first — if one exists it patches missing sessions onto it rather than overwriting.

## Failure modes

1. **Obsidian vault not mounted** (e.g. iCloud desynced) — `preflight_check` fails, `notify_failure` fires, script exits 1. Fix: wait for iCloud sync then re-run manually.
2. **`CLAUDE_BIN` not found or stale** — `preflight_check` fails. Fix: `source ~/.claude/env.sh && echo $CLAUDE_BIN` then verify the binary exists. See `env.sh` resolution chain.
3. **Prompt file missing** — `~/.dotfiles/claude/prompts/daily-retrospective.md` not found, script exits 1 with an error in the log. Fix: restore from git (`git checkout HEAD -- claude/prompts/daily-retrospective.md`).
4. **Claude CLI exits non-zero** — output is logged; `notify_failure` fires. Fix: inspect `$CLAUDE_LOG_DIR/daily-retro-evening-YYYY-MM-DD.log`.

## Recovery steps

```bash
# Re-run manually
bash ~/.dotfiles/claude/crons/daily-retro-evening.sh

# Check the log
tail -50 ~/Library/Logs/claude-crons/daily-retro-evening-$(date +%Y-%m-%d).log

# Verify preflight manually
source ~/.claude/env.sh && echo "CLAUDE_BIN=$CLAUDE_BIN" && echo "VAULT=$OBSIDIAN_VAULT"

# Trigger failure notification manually
source ~/.dotfiles/claude/crons/notify-failure.sh
notify_failure daily-retro-evening ""

# Run stack audit to check last-success marker
cstack-audit run
```

## Related

- Script: `~/.dotfiles/claude/crons/daily-retro-evening.sh`
- Prompt: `~/.dotfiles/claude/prompts/daily-retrospective.md` (shared with morning run)
- Upstream: `daily-retrospective` (morning run, same prompt)
- Downstream: `healthcheck postrun` verifies yesterday's note exists at 11:00 AM
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Log: `~/Library/Logs/claude-crons/daily-retro-evening-YYYY-MM-DD.log`
