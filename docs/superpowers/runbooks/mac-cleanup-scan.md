# Runbook: mac-cleanup-scan

## What this is

Weekly scanner that measures known disk-cleanup targets and writes a ready-to-run Obsidian report when total recoverable space crosses 1 GB. It scans but never deletes — all commands are copy-paste suggestions only.

## Schedule

| Trigger | Value |
|---|---|
| LaunchAgent | `com.godl1ke.claude.mac-cleanup-scan` |
| Crontab.txt | Not listed (launchd-only) |
| Fire time | Sunday 10:00 AM (`Weekday: 0, Hour: 10, Minute: 0` in plist) |

## Purpose / inputs / outputs / side-effects

| Field | Detail |
|---|---|
| Purpose | Scans known cleanup targets every Sunday at 10:00 AM; writes an Obsidian report if recoverable space >= 1 GB |
| Inputs | `CLAUDE_LOG_DIR`, `OBSIDIAN_VAULT` from `env.sh`; optional `THRESHOLD_BYTES` env override (default 1 073 741 824 bytes = 1 GB) |
| Outputs | `04-Knowledge/Mac-Maintenance/YYYY-MM-DD-cleanup-scan.md` written to Obsidian vault when threshold is met; `.last-success-mac-cleanup-scan` touched on success |
| Side-effects | No automatic deletion; calls `notify_failure` on failure |

**Targets scanned:** Claude VM bundle (`~/Library/Application Support/Claude/vm_bundles`), Claude transcripts (`.jsonl` files excluding `memory/`), uv cache (`~/.cache/uv`), npm cache (`~/.npm`), stale claude-mem plugin versions (all but highest semver), known-safe system caches (SiriTTS, GeoServices, Homebrew, helpd), Puppeteer headless Chrome (`~/.cache/puppeteer`).

If total recoverable < 1 GB, the script exits 0 silently — no report is written, but the last-success marker is still touched.

## Failure modes

1. **Obsidian vault not mounted** — `preflight_check` fails, `notify_failure` fires, script exits 1. Fix: wait for iCloud sync then re-kickstart or run manually.
2. **`04-Knowledge/Mac-Maintenance/` directory missing** — `mkdir -p` inside the script creates it on write, so this is not normally a failure mode. If `OBSIDIAN_VAULT` itself is inaccessible the write will fail.
3. **`du` or `stat` errors on a target path** — individual helpers return `0` on error, so a single inaccessible path does not fail the whole scan. The target is silently excluded from the total.
4. **Threshold never crossed** — totally normal; the script exits 0 without writing a note. The last-success marker is still touched so the audit check passes.

## Recovery steps

```bash
# Run manually (uses real threshold)
bash ~/.dotfiles/claude/crons/mac-cleanup-scan.sh

# Force-generate a report by setting a low threshold (1 byte)
THRESHOLD_BYTES=1 bash ~/.dotfiles/claude/crons/mac-cleanup-scan.sh

# Check launchd stdout
tail -f ~/Library/Logs/claude-crons/mac-cleanup-scan-launchd.log
tail -f ~/Library/Logs/claude-crons/mac-cleanup-scan-launchd-err.log

# Kickstart via launchd
launchctl kickstart gui/$(id -u)/com.godl1ke.claude.mac-cleanup-scan

# Check last-success marker
ls -la ~/Library/Logs/claude-crons/.last-success-mac-cleanup-scan

cstack-audit run
```

## Related

- Script: `~/.dotfiles/claude/crons/mac-cleanup-scan.sh`
- LaunchAgent plist: `~/.dotfiles/claude/launchagents/com.godl1ke.claude.mac-cleanup-scan.plist`
- Notify library: `~/.dotfiles/claude/crons/notify-failure.sh`
- Output location: `$OBSIDIAN_VAULT/04-Knowledge/Mac-Maintenance/`
