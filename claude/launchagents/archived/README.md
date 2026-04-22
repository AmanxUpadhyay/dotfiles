# Archived LaunchAgents

Each plist in this directory was previously active under `launchctl gui/<uid>` but is no longer loaded. They are kept in version control so the original schedule, command, and environment definition remain recoverable without git-archaeology.

To reactivate any of them, move the plist back up one level into `claude/launchagents/` and re-run `~/.dotfiles/claude/install-launchagents.sh`. Do not resurrect one of these without checking why it was archived first — most have been superseded by a different automation path, not paused.

## Why each is here

| Plist | Archived on | Replaced by |
|---|---|---|
| `com.godl1ke.claude.daily-retrospective.plist` | 2026-04-07 | Claude Desktop Scheduled Tasks (`daily-retrospective`, cron `57 8 * * *`) |
| `com.godl1ke.claude.daily-retro-evening.plist` | 2026-04-07 | Claude Desktop Scheduled Tasks (`daily-retro-evening`, cron `30 22 * * *`) |
| `com.godl1ke.claude.weekly-report-gen.plist` | 2026-04-07 | Claude Desktop Scheduled Tasks (`weekly-report-gen`, cron `2 17 * * 5`) |
| `com.godl1ke.claude.weekly-finalize.plist` | 2026-04-07 | Claude Desktop Scheduled Tasks (`weekly-finalize`, cron `3 9 * * 1`) |
| `com.godl1ke.claude.healthcheck-preflight.plist` | 2026-04-22 | Retired — was guarding the retro pipeline, which now runs under Claude Desktop Scheduled Tasks with its own failure surface |
| `com.godl1ke.claude.healthcheck-postrun.plist` | 2026-04-22 | Retired — same reason as preflight |

## Where the replacements live

Claude Desktop's Scheduled Tasks configuration is stored at:

```
~/Library/Application Support/Claude/local-agent-mode-sessions/<session-id>/<subsession-id>/scheduled-tasks.json
```

The skill files those tasks execute live under `~/Documents/Claude/Scheduled/<task-id>/SKILL.md`. If you are auditing the scheduled-task pipeline, that JSON file is the source of truth for cron expressions and enabled state.

## Live LaunchAgents (for comparison)

These three plists remain active in `claude/launchagents/`:

- `com.godl1ke.claude-mem-worker.plist` — KeepAlive worker for the claude-mem MCP service (no schedule)
- `com.godl1ke.claude.log-rotate.plist` — Sundays 11:00, prune hook logs older than 30 days + gzip `hooks-fire.log` when it exceeds 10 MB
- `com.godl1ke.claude.mac-cleanup-scan.plist` — Sundays 10:00, scan disk-cleanup targets and write an Obsidian report if recoverable space ≥ 1 GB
