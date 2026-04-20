# Runbook: healthcheck

## What this is

Environment validator and output verifier for the cron stack. Runs in two modes: `preflight` (before crons run) and `postrun` (after, to verify vault output). A single script handles both, invoked by two separate launchd agents.

## Schedule

| Agent label | Mode | Time | Plist |
|---|---|---|---|
| `com.godl1ke.claude.healthcheck-preflight` | `preflight` | 8:50 AM daily | `launchagents/com.godl1ke.claude.healthcheck-preflight.plist` |
| `com.godl1ke.claude.healthcheck-postrun` | `postrun` | 11:00 AM daily | `launchagents/com.godl1ke.claude.healthcheck-postrun.plist` |

Both plists are active (not archived). Crontab.txt also records these times as retired reference.

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Pre-flight: validates env/binary/files before crons run. Post-run: checks vault for recent output files |
| Inputs | Optional positional arg (`preflight` \| `postrun` \| `both`); `CLAUDE_LOG_DIR`, `OBSIDIAN_VAULT`, `ORG_MAP` from `env.sh` |
| Outputs | Status lines appended to `healthcheck.log`; macOS notification on failure |
| Side-effects | Calls `notify_failure` on failure; rotates `healthcheck.log` when it exceeds 100 KB |

**Preflight checks:** `CLAUDE_BIN` executable + `--version` pass; `npx` on PATH; Claude Desktop process running; `OBSIDIAN_VAULT` accessible; `ORG_MAP` valid JSON; all 4 prompt templates present; `CLAUDE_LOG_DIR` writable; 10 required vault directories exist.

**Postrun checks:** yesterday's daily note exists in `07-Daily/`; on Sat/Sun/Mon, last week's weekly summary exists.

## Failure modes

1. **Claude Desktop not running** — preflight logs `"Claude Desktop not running"` and fails. Fix: open Claude Desktop before the 8:50 AM fire time.
2. **`CLAUDE_BIN` stale** — binary path exists but `--version` hangs or fails. Fix: `source ~/.claude/env.sh && $CLAUDE_BIN --version`. Resolution chain in `env.sh` tries `~/.local/bin/claude`, `~/.npm-packages/bin/claude`, `/opt/homebrew/bin/claude`.
3. **Vault directory missing** — a required subdirectory (e.g. `07-Daily`, `01-LXS/reports/weekly`) was deleted or renamed. Fix: recreate the directory in Obsidian or via mkdir and re-run.
4. **Postrun: yesterday's note missing** — daily-retrospective failed or wrote to the wrong location. Fix: run `daily-retrospective.sh` manually, check its log, then re-run `healthcheck.sh postrun`.
5. **Log rotation race** — `healthcheck.log` is briefly missing while being rotated. Harmless; next write recreates it.

## Recovery steps

```bash
# Run preflight manually
bash ~/.dotfiles/claude/crons/healthcheck.sh preflight

# Run postrun manually
bash ~/.dotfiles/claude/crons/healthcheck.sh postrun

# Run both phases
bash ~/.dotfiles/claude/crons/healthcheck.sh both

# Check the log
tail -50 ~/Library/Logs/claude-crons/healthcheck.log

# Kickstart via launchd
launchctl kickstart gui/$(id -u)/com.godl1ke.claude.healthcheck-preflight
launchctl kickstart gui/$(id -u)/com.godl1ke.claude.healthcheck-postrun

# Check launchd stdout
tail -f ~/Library/Logs/claude-crons/healthcheck-preflight-launchd.log
tail -f ~/Library/Logs/claude-crons/healthcheck-postrun-launchd.log

# Stack audit for overall health
cstack-audit run
```

## Related

- Script: `~/.dotfiles/claude/crons/healthcheck.sh`
- LaunchAgent plists: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.healthcheck-preflight.plist`, `…healthcheck-postrun.plist`
- Downstream: all other crons depend on the env this validates
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Log: `~/Library/Logs/claude-crons/healthcheck.log` (rotating, max ~100 KB)
