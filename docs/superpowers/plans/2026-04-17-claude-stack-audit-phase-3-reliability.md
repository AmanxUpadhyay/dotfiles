# Claude Stack Audit — Phase 3 Implementation Plan (Reliability REL002–REL009)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add 8 reliability checks (REL002–REL009) that catch the class of bugs that have historically caused silent failures (the April 2026 `CLAUDE_BIN` incident, missing `set -euo pipefail`, etc.).

**Architecture:** Each check is a new `@register`ed class in `src/claude_stack_audit/checks/reliability.py`.

**Branch:** `fix/hook-audit-28-bugs-env-centralized`.

---

## Files

| Path | Change |
|------|--------|
| `src/claude_stack_audit/checks/reliability.py` | Append 8 new check classes |
| `tests/test_reliability.py` | Append tests (2+ per check where meaningful) |

---

## Checks (one subagent task each)

### REL002 — `SetEuoPipefail`

Every bash script has `set -euo pipefail` within the first 10 lines. Missing → HIGH.

Fixture: `session-stop.sh` has it; `session-start.sh` has it; a new `bare-no-euo.sh` will not.

### REL003 — `ErrOrExitTrap`

Every script in `claude/crons/` has `trap <handler> ERR` OR `trap <handler> EXIT`. Missing → MEDIUM.

Fixture: Need a cron script in fake_dotfiles with a trap and one without. Extend fixture in conftest (add `cron-with-trap.sh` and `cron-without-trap.sh` to `claude/crons/`).

### REL004 — `ClaudeBinResolved`

Grep each bash script for hardcoded paths like `/Users/*/.local/bin/claude` or `~/.local/bin/claude` — if found, flag HIGH. Also flag the raw string `claude` used as a command without `$CLAUDE_BIN` indirection when the path prefix is suspicious. Pragmatic heuristic: if a line has `claude` as a command AND doesn't reference `$CLAUDE_BIN` on the same line, and references an absolute `/*/claude` path, flag it.

Simpler: if script contains hardcoded `/claude` absolute path (e.g. `/Users/.../bin/claude`, `~/.npm-packages/bin/claude`) and NO `$CLAUDE_BIN` reference, flag HIGH.

Fixture: Add `bad-claude-path.sh` that has `~/.npm-packages/bin/claude ...`.

### REL005 — `CronIdempotencyGuard`

Each script in `claude/crons/` has a guard pattern: `flock`, `[[ -f "...last-success*" ]]`, `--skip-if-done`, or similar marker-file check. Missing → MEDIUM.

Heuristic: look for `flock` OR `last-success` OR `.last-run` OR `skip-if-done` substring. If none present → finding.

### REL006 — `CompanionTestPresent`

Each hook/cron script has a companion test at `tests/<name>.bats` or `tests/test_<name>.py`. Scope for v1: just check whether `~/.dotfiles/tests/` exists and has any matching file. If no tests dir exists at all, emit one Info finding about that rather than flooding with MEDIUM findings.

For v1: if `~/.dotfiles/tests/` doesn't exist → one MEDIUM finding aggregated: "No test directory for hook/cron scripts".

### REL007 — `CronHealthcheckMarker`

Each cron script has a `.last-success-*` touch/write pattern, AND a healthcheck.sh references the marker. Pragmatic v1: just check whether every cron script writes to `.last-success-*` path.

Heuristic: for each script in `claude/crons/`, check body for `last-success`. If not → HIGH.

### REL008 — `LongOpTimeout`

For subprocess-ish patterns in Python-invoking scripts (`claude` calls in particular), check if there's a timeout mechanism (`timeout Xs` command wrapper, `--timeout` flag, ulimit). Pragmatic: if script has `claude` invocation AND no `timeout` keyword → MEDIUM.

### REL009 — `JqDefensiveDefaults`

For each script using `jq`, check that `jq` calls use `// empty` or `// []` or `// null` or `// "default"` defensive defaults. Pragmatic: if script body has `jq` but no `// ` present → LOW.

---

## Task Flow

One subagent per check (8 tasks). Each task:
1. Extend fixture if needed (REL002 no / REL003 yes / REL004 yes / REL005 N/A / REL006 N/A / REL007 N/A / REL008 N/A / REL009 N/A — most use existing fixture)
2. Write tests (1-3 per check)
3. Implement check class
4. Commit `feat(claude-stack-audit): add RELXXX <name> check`

Coverage gate (90% on checks/) is enforced. If a check adds uncovered branches, tests must cover them.

## Task P3-9: Refresh baseline after phase 3

Re-run `cstack-audit run` on real dotfiles, commit the report.
