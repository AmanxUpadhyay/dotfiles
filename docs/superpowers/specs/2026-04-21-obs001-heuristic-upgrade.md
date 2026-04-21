# Spec — OBS001 heuristic upgrade

**Date**: 2026-04-21
**Status**: approved (Batch 2, item 7)
**Related**: `docs/superpowers/runbooks/stack-audit.md` §Observability →
OBS001, runbook §Future improvements.

---

## Problem

`OBS001 log path consistency` uses pure prefix-matching on redirect targets.
Any `>`/`>>`/`tee` write to a path that doesn't start with an approved log
prefix gets flagged. This produces known false positives where a script
writes **product output** (notes, HTML, navigation files) using the same
shell-redirect idiom as a log write.

Current baseline on `main` (2026-04-21): **5 OBS001 findings**, of which 4
are documented false positives and 1 is a `${VAR:-default}` resolver gap
tracked separately.

| # | Script | Target | Class |
|---|---|---|---|
| 1 | `crons/mac-cleanup-scan.sh` | `$NOTE_PATH` | note (.md to Obsidian vault) |
| 2 | `crons/notify-failure.sh` | `$note_path` | note (.md to Obsidian inbox) |
| 3 | `crons/notify-failure.sh` | `$logfile` | function parameter (runtime log path) |
| 4 | `hooks/breadcrumb-writer.sh` | `$BREADCRUMB_DIR/breadcrumbs.md` | breadcrumb (.md per-repo nav) |
| 5 | `hooks/auto-format.sh` | `$DRIFT_LOG` | genuine log; resolver can't expand `${VAR:-default}` — out of scope |

---

## Design

Apply four filters **before** severity classification in
`LogPathConsistency.run`. Each filter returns "skip" independently; the
write must pass all four to be classified as a finding.

### Rule 1 — variable-name intent signal

Skip when the raw target path begins with `$VAR` / `${VAR}` and `VAR`
matches the case-insensitive regex `\b(NOTE|BREADCRUMB|DOC|VAULT_NOTE)\b`.

Rationale: the variable name is the cheapest intent signal available. A
name like `NOTE_PATH` or `breadcrumb_dir` is a human declaration that the
file is product output, not a log.

Scope: `VAULT_NOTE` is listed explicitly (not just `VAULT`) because
`VAULT` alone could collide with unrelated variable names. `LOG` is
deliberately **not** in this list — `$LOGFILE`, `$DRIFT_LOG` are genuine
log targets that we want to keep checking.

Catches FPs #1, #2, #4.

### Rule 2 — product extension skip

Skip when the resolved path ends in `.md`, `.html`, or `.htm`.

Rationale: these are document formats, not log formats. Logs end in
`.log`, `.txt`, `.jsonl`, or have no extension. This rule is belt-and-
braces for FP #4 (`$BREADCRUMB_DIR/breadcrumbs.md` — literal `.md`
visible in the raw path even without resolving) and catches future
scripts that write product `.md`/`.html` under a variable the author
didn't name `NOTE`.

### Rule 3 — vault prefix allowlist

Skip when the resolved path starts with `$OBSIDIAN_VAULT`,
`~/Library/Mobile Documents/`, or `iCloud Drive`.

Rationale: iCloud-synced Obsidian vaults are product-output roots by
definition — nothing written there is an operational log.

This is supplementary to Rules 1 and 2 — it catches writes where the
variable name is generic (e.g. `$OUTPUT`) but the resolved prefix is a
known product root. For the four documented FPs, Rule 1 and Rule 2
together are sufficient; Rule 3 is forward-looking.

### Rule 4 — inline escape hatch

Skip when the current redirect line OR any of the 3 preceding lines
contains a comment matching:

```
# audit-ignore: OBS001[, OBS002[, ...]] [<free-text reason>]
```

**Syntax:**
- Marker literal: `audit-ignore:` (colon required). Chosen to match the
  `# noqa:` / `# type: ignore` family of inline-suppression conventions.
- IDs: one or more check IDs, comma- or whitespace-separated. Pattern:
  `[A-Z]{3,5}\d{3}`.
- Reason: free-text after the IDs. Parser does **not** enforce a reason.
  Convention (documented in the runbook) is to always include one. This
  matches how `# noqa` works — the linter accepts it bare, humans supply
  context.
- Lookback: 3 lines before the redirect + the redirect's own line. Three
  lines covers the common "comment + `mkdir -p` + write" idiom used
  in `notify-failure.sh`.

**Why not enforce a reason:** enforcement adds parser complexity for
marginal benefit — an empty `# audit-ignore: OBS001` is a code-review
signal, not a parser problem. The reviewer can reject the PR. Keeping
the parser minimal also means the escape hatch degrades gracefully
across future check-ID additions.

Catches FP #3 (cross-function `$logfile` parameter — no static
resolution possible; author must annotate the known-safe write).

### Ordering

Filters run in order: Rule 1 → Rule 2 → Rule 3 → Rule 4 → existing
severity logic. Short-circuit on first match. Cost: one regex match
per filter, negligible relative to the existing per-line scan.

---

## Test scenarios

TDD: each below starts as a failing test, driven green by the
implementation.

1. **Variable-name `NOTE_PATH` skip** — script assigns
   `NOTE_PATH="$OBSIDIAN_VAULT/foo.md"` and writes `> "$NOTE_PATH"` —
   expect no OBS001 finding.
2. **Variable-name case-insensitive `note_path`** — same with
   lowercase `note_path` — expect no finding.
3. **Variable-name `BREADCRUMB_DIR`** — write to
   `"$BREADCRUMB_DIR/breadcrumbs.md"` — expect no finding.
4. **Extension `.md` skip** — literal path `> /tmp/report.md` — expect no
   finding (document format, even if under `/tmp`).
5. **Extension `.html` skip** — literal path `> /tmp/index.html` — expect
   no finding.
6. **Vault prefix `$OBSIDIAN_VAULT`** — path `$OBSIDIAN_VAULT/inbox/x.txt`
   — expect no finding.
7. **Escape hatch same line** — `echo x > /tmp/sneaky.log  # audit-ignore: OBS001 — notify-failure relays this to caller`
   — expect no finding.
8. **Escape hatch preceding line** — comment line then redirect —
   expect no finding.
9. **Escape hatch 3 lines back still skips; 4 lines back does not**.
10. **Escape hatch with multiple IDs** — `# audit-ignore: OBS001, OBS002` — expect no finding.
11. **Negative — escape hatch for different ID** — `# audit-ignore: OBS002` on a redirect to `/tmp/foo.log` — **must still flag** OBS001.
12. **Negative — LOG variable still flagged** — `LOGFILE="/tmp/x.log"; echo >> "$LOGFILE"` — must still flag HIGH (Rule 1 excludes
    LOG/LOGFILE intentionally).
13. **Negative — `.log` extension still flagged under `/tmp`** — must
    stay HIGH.

---

## Non-goals

- Fixing the `${VAR:-default}` resolver gap that leaves `$DRIFT_LOG` as
  a finding. Separate issue; tracked for a future cycle.
- Cross-function parameter flow analysis. The escape hatch is the
  pragmatic substitute — the `$logfile` case is explicitly one the
  resolver cannot trace.
- Config-file allowlist (`[tool.cstack-audit]` section) from the runbook
  "Future improvements" list. Rules 1–3 cover the documented FPs; a
  config-driven allowlist adds complexity without a concrete need yet.

---

## Deliverables

1. Spec — this file.
2. Implementation — `claude-stack-audit/src/claude_stack_audit/checks/observability.py` with new rules applied in `LogPathConsistency.run`.
3. Tests — `claude-stack-audit/tests/test_observability.py` with the 13 scenarios above.
4. Inline escape hatch on `crons/notify-failure.sh` lines writing to `$logfile`.
5. Runbook update — remove "Known false positives" block under OBS001 in `docs/superpowers/runbooks/stack-audit.md`; replace with brief docstring about the escape hatch and variable-name convention.
6. Re-audit — `cstack-audit run` must show OBS001 drop from 5 → ≤1 (only `$DRIFT_LOG` remains, separate issue).

---

## Success criteria

- All existing tests still green.
- 13 new tests green.
- Coverage ≥ 90% on `checks/observability.py`.
- `ruff check` clean, `ruff format` clean.
- Real-dotfiles re-audit: OBS001 findings drop from 5 to 1 (the
  `$DRIFT_LOG` resolver gap, explicitly out of scope).
- Runbook no longer carries a "known FPs" list under OBS001.
