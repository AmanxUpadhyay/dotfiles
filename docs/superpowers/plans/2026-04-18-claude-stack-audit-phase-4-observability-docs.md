# Claude Stack Audit — Phase 4 Implementation Plan (Observability OBS002-006 + Documentation DOC002-007)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Add 11 more checks — 5 observability + 6 documentation — covering structured logging, failure notifications, rotation, doc/ADR/runbook coverage.

**Branch:** `fix/hook-audit-28-bugs-env-centralized`.

---

## Checks

### Observability

- **OBS002** `StdoutCaptureWithTimestamp` — scripts invoking `claude` capture stdout+stderr with ISO8601 timestamps. Heuristic: if script has `$CLAUDE_BIN` and pipes through something with `%F` / `%T` / `date` → pass; else MEDIUM.
- **OBS003** `NotifyFailureSourced` — every script in `claude/crons/` sources or calls `notify-failure.sh` (or equivalent). Missing → HIGH.
- **OBS004** `DurationStatusMarkers` — scripts emit `duration_ms=` or `status=` markers. Missing → MEDIUM.
- **OBS005** `LogRotationPolicy` — at least ONE script exists that handles log rotation (grep for `logrotate`, `find -mtime -delete`, `gzip`). If no such script in the dotfiles → MEDIUM aggregate finding.
- **OBS006** `HookHandlerExists` — each `hooks.*.command` path in `settings.json` resolves to an existing, executable file. Missing → HIGH.

### Documentation

- **DOC002** `EnvVarCommented` — each `export FOO=...` in env.sh has a comment within the 3 lines preceding. Missing → MEDIUM per var.
- **DOC003** `ClaudeReadmePresent` — `~/.dotfiles/claude/README.md` exists. Missing → HIGH.
- **DOC004** `AdrCoverage` — `~/.dotfiles/docs/superpowers/adr/` OR `~/vault/.../Decisions/` contains at least 1 ADR. Absent → MEDIUM.
- **DOC005** `RunbookPresent` — each cron script has a matching runbook at `docs/superpowers/runbooks/<name>.md`. Missing → HIGH.
- **DOC006** `CrontabCommentsPresent` — each active entry in `crontab.txt` has a comment line within 2 lines above. Missing → MEDIUM.
- **DOC007** `HookSettingsDocumented` — either `docs/settings.hooks.md` exists OR `settings.json` hooks have inline comments (note: JSON doesn't support comments; this is an aggregate presence check — just verify the doc file exists). Missing → MEDIUM.

---

## Task Flow

- **P4-1:** Combined OBS002 + OBS003 (atomic Writes)
- **P4-2:** Combined OBS004 + OBS005 + OBS006
- **P4-3:** Combined DOC002 + DOC003 + DOC004
- **P4-4:** Combined DOC005 + DOC006 + DOC007
- **P4-5:** Refresh baseline, commit.

Each check: TDD, coverage must stay ≥90%, separate conventional commit per check.
