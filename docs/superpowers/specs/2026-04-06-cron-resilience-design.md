# Cron Resilience: Fix + Harden Obsidian Report Automation

**Date**: 2026-04-06
**Status**: Draft
**Scope**: Fix broken `CLAUDE_BIN` path, add resilience guards, backfill missing reports

---

## Context

Three cron jobs generate Obsidian vault reports (daily retros, weekly drafts, weekly finalization) by invoking Claude Code CLI in headless mode. All three have been failing since Apr 5 because `env.sh` hardcodes a stale path to the `claude` binary (`~/.npm-packages/bin/claude`), which no longer exists after the CLI moved to `~/.local/bin/claude` via the native installer. No daily notes were generated for Sunday Apr 5 or Monday Apr 6, and the Monday weekly finalization also failed. The failure handler (`notify-failure.sh`) fired correctly — macOS notifications were sent and error notes were written to `00-Inbox/` — but the user was not at their Mac to see them in time.

**Goal**: Fix the immediate break, prevent this class of failure from recurring silently, and backfill missing reports.

---

## Files to Modify

| File | Change |
|------|--------|
| `~/.dotfiles/claude/env.sh` | Fix `CLAUDE_BIN`, add dynamic resolution chain + `preflight_check()` |
| `~/.dotfiles/claude/crons/daily-retrospective.sh` | Add preflight call + success marker |
| `~/.dotfiles/claude/crons/weekly-report-gen.sh` | Add preflight call + success marker |
| `~/.dotfiles/claude/crons/weekly-finalize.sh` | Add preflight call + success marker |
| `~/.dotfiles/claude/crontab.txt` | Add healthcheck entries (08:50, 11:00) |

## New Files

| File | Purpose |
|------|---------|
| `~/.dotfiles/claude/crons/healthcheck.sh` | Pre-flight env validation + post-run marker checks |

---

## 1. Dynamic Binary Resolution (`env.sh`)

Replace the hardcoded `CLAUDE_BIN` default (line 10) with a resolution chain:

```bash
# Resolve CLAUDE_BIN: respect env override, fall back to known install paths
if [[ -z "${CLAUDE_BIN:-}" ]] || [[ ! -x "${CLAUDE_BIN:-}" ]]; then
  for _candidate in \
    "$HOME/.local/bin/claude" \
    "$HOME/.npm-packages/bin/claude" \
    "/opt/homebrew/bin/claude"; do
    if [[ -x "$_candidate" ]]; then
      CLAUDE_BIN="$_candidate"
      break
    fi
  done
  unset _candidate
fi
export CLAUDE_BIN
```

**Behavior**: If `CLAUDE_BIN` is already set and points to a valid executable, it's used as-is. Otherwise, tries known paths in priority order. `~/.local/bin` is first (current native installer location).

---

## 2. Pre-flight Check Function (`env.sh`)

Add after the exports:

```bash
preflight_check() {
  local caller="${1:-unknown}"
  local errors=()

  [[ ! -x "${CLAUDE_BIN:-}" ]] && errors+=("CLAUDE_BIN not found or not executable: ${CLAUDE_BIN:-<unset>}")
  [[ ! -d "$OBSIDIAN_VAULT" ]]  && errors+=("OBSIDIAN_VAULT not accessible: $OBSIDIAN_VAULT")
  [[ ! -f "$ORG_MAP" ]]         && errors+=("ORG_MAP not found: $ORG_MAP")

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "[$(date)] PREFLIGHT FAILED for $caller:" >&2
    printf '  - %s\n' "${errors[@]}" >&2
    return 1
  fi
  return 0
}
```

**Called from each cron script** after both `source` lines:

```bash
if ! preflight_check "$(basename "$0" .sh)"; then
  echo "[$(date)] PREFLIGHT FAILED" >> "$LOGFILE"
  notify_failure "$(basename "$0" .sh)-preflight" "$LOGFILE"
  exit 1
fi
```

---

## 3. Run Success Markers (cron scripts)

Each cron script touches a marker file on success. Add before the final `exit`:

```bash
if [[ $STATUS -eq 0 ]]; then
  touch "$CLAUDE_LOG_DIR/.last-success-$(basename "$0" .sh)"
fi
```

Produces:
- `~/Library/Logs/claude-crons/.last-success-daily-retrospective`
- `~/Library/Logs/claude-crons/.last-success-weekly-report-gen`
- `~/Library/Logs/claude-crons/.last-success-weekly-finalize`

---

## 4. Healthcheck Cron (`healthcheck.sh`)

Two scheduled runs with different check profiles:

### 08:50 — Pre-flight validation

Runs 7 minutes before the daily retro. Validates the environment:

1. `CLAUDE_BIN` resolves to an executable
2. `$CLAUDE_BIN --version` exits 0 (binary is functional)
3. `$OBSIDIAN_VAULT` directory is accessible
4. `$ORG_MAP` exists and is valid JSON (`python3 -m json.tool`)
5. All 3 prompt template files exist (`daily-retrospective.md`, `weekly-report-gen.md`, `weekly-finalize.md`)
6. `$CLAUDE_LOG_DIR` is writable

### 11:00 — Post-run marker verification

Runs ~2h after the daily retro. Checks marker freshness:

| Marker | Threshold | Rationale |
|--------|-----------|-----------|
| `daily-retrospective` | < 2h15m old | Daily retro fires at 08:57; by 11:00 the marker should be ~2h old |
| `weekly-report-gen` | < 3 days old (checked Sat+) | Fires Friday 17:02; by Saturday 11:00 it's ~18h old. Only relevant Sat onwards |
| `weekly-finalize` | < 3 days old (checked Tue+) | Fires Monday 09:03; by Tuesday 11:00 it's ~26h old. Only relevant Tue onwards |

The post-run check skips weekly markers on days where the cron hasn't had a chance to fire yet.

### Failure handling

Same path as all cron scripts: `notify_failure "healthcheck" "$LOGFILE"` — macOS notification + Obsidian inbox note.

### Success logging

Appends a timestamp to `$CLAUDE_LOG_DIR/healthcheck.log`.

### Crontab additions

```
50 8  * * * /Users/godl1ke/.dotfiles/claude/crons/healthcheck.sh preflight
0  11 * * * /Users/godl1ke/.dotfiles/claude/crons/healthcheck.sh postrun
```

The script accepts a `preflight` or `postrun` argument to determine which checks to run. No argument runs both (useful for manual invocation).

---

## 5. Backfill Missing Reports

After `env.sh` is fixed, manually invoke each cron script with an overridden `DATE_HINT`:

```bash
# 1. Sunday Apr 5 daily retrospective
DATE_HINT="Today is 2026-04-05 (Sunday)." \
  /Users/godl1ke/.dotfiles/claude/crons/daily-retrospective.sh

# 2. Monday Apr 6 daily retrospective
DATE_HINT="Today is 2026-04-06 (Monday)." \
  /Users/godl1ke/.dotfiles/claude/crons/daily-retrospective.sh

# 3. Monday W15 weekly finalization
DATE_HINT="Today is 2026-04-06 (Monday)." \
  /Users/godl1ke/.dotfiles/claude/crons/weekly-finalize.sh
```

**Note**: The cron scripts currently construct `DATE_HINT` on line 29 using `$(date)`. The backfill approach overrides this by setting `DATE_HINT` as an env var before invocation. This requires a small change to the scripts: check if `DATE_HINT` is already set before overwriting it:

```bash
DATE_HINT="${DATE_HINT:-Today is $(date +%Y-%m-%d) ($(date +%A)).}"
```

This change is applied to all three cron scripts as part of the implementation.

---

## Verification Plan

1. **Unit checks after env.sh changes:**
   - `source env.sh && echo "$CLAUDE_BIN"` prints `/Users/godl1ke/.local/bin/claude`
   - `source env.sh && preflight_check "test"` returns 0
   - With `CLAUDE_BIN=/nonexistent source env.sh`, resolution chain kicks in and finds `~/.local/bin/claude`

2. **Healthcheck dry run:**
   - `./healthcheck.sh preflight` — all checks pass, writes to healthcheck.log
   - `./healthcheck.sh postrun` — marker checks run (may warn about stale markers until first successful cron)

3. **Backfill verification:**
   - After each backfill run, confirm the note exists in the vault via `mcp__obsidian__read_note` or by checking the filesystem
   - `2026-04-05-sunday.md` should have sessions from Saturday Apr 4's work
   - `2026-04-06-monday.md` should capture Sunday Apr 5's work (if any)
   - W15 weekly finalization should update `period: friday-draft` → `period: final`

4. **Crontab install:**
   - `crontab ~/.dotfiles/claude/crontab.txt` and verify with `crontab -l`
   - Wait for next scheduled run (or manually trigger) and check logs

5. **End-to-end: simulate a broken binary:**
   - Set `CLAUDE_BIN=/nonexistent` and run `./healthcheck.sh preflight`
   - Confirm: macOS notification fires, error note appears in `00-Inbox/`
   - Confirm: resolution chain in `env.sh` would have self-healed (unset `CLAUDE_BIN` and re-source)
