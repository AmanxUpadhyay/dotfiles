# ADR: Hook Observability Audit

**Date:** 2026-04-21
**Status:** Accepted (keep all hooks; add data-driven review cadence)

## Context

The `feat/observability-foundation` branch wired a shared NDJSON fire logger into all 13 Claude Code hooks (see `claude/libs/hooks-log.sh`). With live data now flowing into `~/Library/Logs/claude-crons/hooks-fire.log`, we can audit the hook stack on real fire counts instead of intuition.

The plan originally listed three hooks as "flag for review" candidates:

- `stop-notification.sh` — cosmetic Glass-sound notification on task completion
- `auto-test.sh` — runs pytest on every `.py` edit, 60s async timeout
- `test-fix-detector.sh` — nudges Claude to log bugs after editing test files

## Evidence (2026-04-21 21:13, ~90 minutes of active development)

Total fires: **379**.

**By hook (top 10):**

| Hook | Fires | Per minute | Event |
|---|---|---|---|
| pr-gate.sh | 98 | 1.09 | PreToolUse (Bash) |
| auto-format.sh | 74 | 0.82 | PostToolUse (Write\|Edit\|MultiEdit) |
| safety-guards.sh | 63 | 0.70 | PreToolUse (Bash) |
| protect-files.sh | 39 | 0.43 | PreToolUse (Write\|Edit\|MultiEdit) |
| auto-test.sh | 38 | 0.42 | PostToolUse (async) |
| test-fix-detector.sh | 37 | 0.41 | PostToolUse |
| prompt-injection-guard.sh | 17 | 0.19 | UserPromptSubmit |
| session-start.sh | 7 | 0.08 | SessionStart |
| stop-notification.sh | 2 | 0.02 | Stop (async) |
| session-stop.sh | 2 | 0.02 | Stop (sync) |

**By event:** PreToolUse 200, PostToolUse 149, UserPromptSubmit 17, SessionStart 7, Stop 4, SessionEnd 2.

## Findings

1. **No hook is pathologically hot.** The highest fire rate is `pr-gate.sh` at 1.09 fires/minute — well within budget for a hook that does a cheap early-exit on non-PR commands.

2. **Stop events are surprisingly rare (4 in 90 min).** Expected every turn-end, but the log only captured 4 total — likely because the hooks-log wiring landed mid-session (commit `b3a8eee`) and excluded earlier turns. Re-audit after a full day of post-wiring activity.

3. **`stop-notification.sh` fires 2× per hour.** Lowest-volume "cosmetic" hook. Retaining costs nothing; removing saves 2 osascript calls per hour. Keep.

4. **`auto-test.sh` at 0.42 fires/min is within budget** but has a 60s async timeout ceiling. Under heavy test churn this could queue up. Not urgent; monitor.

5. **`test-fix-detector.sh` fires on every edit (0.41/min).** Pure nudge — emits an additionalContext reminder about Bug Jar documentation. Cheap but has indirect cost (token consumption in Claude's context on every edit). Candidate for matcher tightening (e.g. only fire when filename matches `*test*` or `*spec*`).

## Decisions

### Decision 1 — No retirements today

The fire data doesn't justify any immediate retirements. All hooks are serving their stated purpose at reasonable cost. Revisit after 7 days of observation data (not 90 minutes).

### Decision 2 — Pre-register three future optimizations

Each gated by a specific data threshold; if observed, cheap to execute.

| Target | Trigger condition | Action |
|---|---|---|
| `test-fix-detector.sh` matcher | ≥ 500 fires / week with < 3 Bug-Jar entries created | Tighten matcher to `*test*\|*spec*\|*_test.py` |
| `auto-test.sh` matcher | ≥ 3 cases of blocked 60s-timeouts in hooks-fire.log | Add per-project opt-in via `.claude/config.toml` |
| `stop-notification.sh` | User asks to mute notifications OR fires > 50/day (loops) | Retire the hook; drop the osascript dependency |

### Decision 3 — Weekly `/hook-health` review

The new `/hook-health` command (see `claude/commands/hook-health.md`) runs nightly via Claude Desktop Scheduled Tasks and writes a digest to `04-Knowledge/Hook-Health/YYYY-MM-DD-hook-health.md`. Review weekly to catch drift against the triggers above.

## Consequences

- **Positive:** Retirement debate becomes data-driven. No hook culled based on feel.
- **Negative:** Over-engineering that doesn't hit a trigger stays indefinitely. Mitigated by the weekly review cadence.
- **Reversal:** Each trigger fires a retirement PR that takes <30 min to execute. Low cost if reversed.

## Related

- Plan: `~/.claude/plans/honest-self-assessment-what-i-recursive-engelbart.md` (to be split into spec + plan in `docs/superpowers/`)
- Library: `claude/libs/hooks-log.sh`
- Dashboard command: `claude/commands/hook-health.md`
- Session hook regression suite: `tests/session_hooks.bats`
