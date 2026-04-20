# ADR: Migrate from crontab to launchd agents

**Date**: 2026-04-19
**Status**: Accepted
**Decider**: Aman Upadhyay

---

## Context

The Claude automation stack originally scheduled recurring tasks (daily retros, weekly reports, healthchecks, mac-cleanup scan) via user crontab entries in `~/.dotfiles/claude/crontab.txt`. This approach had several pain points discovered during the April 2026 audit:

- cron jobs silently fail if the user's shell environment is not sourced (no `$HOME/.claude/env.sh` loaded by default in cron's minimal environment)
- No built-in stdout/stderr capture; log paths had to be manually redirected in each cron line
- No per-job environment variable injection without wrapping every entry in `env VAR=val`
- `CLAUDE_BIN` path went stale after CLI updates and cron gave no visibility into the failure until `notify-failure.sh` fired (see memory entry: "Cron CLAUDE_BIN break Apr 2026")
- macOS cron (via `/usr/sbin/cron`) does not respect system sleep/wake; jobs missed during laptop closure are simply skipped

launchd is the native macOS service manager and resolves all of the above.

---

## Decision

Migrate all scheduled Claude automation tasks from crontab to launchd `.plist` agents in `~/.dotfiles/claude/launchagents/`, loaded into `~/Library/LaunchAgents/` via symlinks during `install.sh`.

Each plist:
- Sets `EnvironmentVariables` with `HOME` and `PATH` so scripts can reliably source `env.sh`
- Sets `StandardOutPath` and `StandardErrorPath` to `~/Library/Logs/claude-crons/<name>-launchd.log`
- Uses `StartCalendarInterval` for wall-clock scheduling (equivalent to cron syntax)
- Is named `com.godl1ke.claude.<script-name>.plist` for clear namespace ownership

Scripts themselves are unchanged; launchd is a drop-in scheduler replacement.

---

## Consequences

**Positive**
- Structured per-job log files in `~/Library/Logs/claude-crons/` — viewable in Console.app and greppable
- Environment variables are explicit and auditable in the plist, not implicit from shell profile loading order
- `StartCalendarInterval` fires missed jobs on next wake if the machine was asleep at scheduled time
- launchd managed by `launchctl` — clear load/unload/list semantics; no crontab syntax errors

**Negative**
- plists are verbose XML; adding a new scheduled task requires writing a full plist file rather than a single crontab line
- Requires `launchctl load`/`unload` when adding/removing agents (handled by `install.sh`)
- `StartCalendarInterval` semantics differ slightly from cron: it fires once per calendar interval match, not at a fixed offset from last run

**Neutral**
- Existing `claude/crontab.txt` retained for reference but is no longer loaded into the system crontab
