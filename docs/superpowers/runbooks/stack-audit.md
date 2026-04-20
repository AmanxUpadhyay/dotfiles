# Runbook — claude-stack-audit

**What this is**: operational guide for the `cstack-audit` CLI — when to run it,
how to interpret findings, how to recover from failures, and how each check ID
maps to a fix.

---

## Quick reference

| Task | Command |
|------|---------|
| Run full audit | `cstack-audit run` |
| Fast sanity check | `cstack-audit run --quick` |
| Single criterion | `cstack-audit run --only reliability` |
| A/B compare | `cstack-audit run --tag before-fix` |
| List all checks | `cstack-audit list-checks` |
| Validate env | `cstack-audit validate` |

**Reports land in** `~/.dotfiles/docs/superpowers/audits/stack-audit.{md,json}` —
single canonical path, always overwritten (no date prefix). Tagged runs
(`cstack-audit run --tag <slug>`) write `stack-audit--<slug>.{md,json}` with
the same overwrite semantics. Git-tracked. Use `git log -p docs/superpowers/audits/stack-audit.md`
to walk the score trend. Policy pinned by
`docs/superpowers/adr/2026-04-20-audit-snapshot-policy.md`.

---

## Exit codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Clean run, no Critical/High | Nothing to do |
| 1 | Has Critical or High findings | Inspect report; plan fixes |
| 2 | Environment validation failed | Install shellcheck + jq |
| 3 | A check crashed (META001 present) | Open an issue; submit a fix |

---

## Common recovery paths

### Exit 2 — `error: shellcheck not found`

```bash
brew bundle --file ~/.dotfiles/Brewfile
cstack-audit validate
```

### Exit 2 — dotfiles root missing

If `~/.dotfiles` doesn't exist (fresh machine): clone dotfiles, run
`install.sh`.

### Exit 3 — META001 in findings

A check class raised an unexpected exception. The META001 finding's `details`
field shows which check crashed and the exception. Steps:

1. Reproduce with `cstack-audit run --only <criterion-of-crashed-check>`.
2. File an issue against `claude-stack-audit/` with the exception text.
3. Tool still produced a report with the crash recorded — other checks ran.

---

## Finding-to-fix map

### Inventory (INV*)

All Info severity. Never affect the score. They populate the report's
inventory section and let you spot drift (e.g. a new cron appeared but no
runbook exists yet).

### Reliability (REL*)

- **REL001** `shellcheck` → run `shellcheck <file>` locally; follow the wiki
  URL printed in the error.
- **REL002** missing `set -euo pipefail` → add it as line 2.
- **REL003** missing `trap` → add `trap 'notify-failure.sh' ERR` near top.
- **REL004** hardcoded `claude` path → replace with `$CLAUDE_BIN` and source
  `env.sh`; the resolution chain handles installer changes.
- **REL005** no idempotency guard → add `flock` or a `.last-success` marker
  check.
- **REL006** no `~/.dotfiles/tests/` → create it and add bats/pytest tests
  for critical hooks/crons.
- **REL007** no `last-success` marker write → `touch
  "$HOME/Library/Logs/claude-crons/.last-success-<name>"` on success.
- **REL008** claude call without timeout → wrap with `timeout <N>s`.
- **REL009** `jq` without defensive default → use `jq '.foo // empty'`.

### Observability (OBS*)

- **OBS001** log to non-approved path → use `$CLAUDE_LOG_DIR` or
  `~/Library/Logs/claude-crons/`.

  **Known false positives** (do not "fix" in the scripts — the check cannot
  tell these apart from logs with its current heuristic):

  | Script | Redirect target | Why it's not a log |
  |---|---|---|
  | `crons/mac-cleanup-scan.sh` | `$NOTE_PATH` | Obsidian knowledge note under `04-Knowledge/Mac-Maintenance/`. Product output. |
  | `crons/notify-failure.sh` | `$note_path` | User-facing error note in the Obsidian vault inbox. Product output. |
  | `hooks/breadcrumb-writer.sh` | `$BREADCRUMB_DIR/breadcrumbs.md` | Per-repo navigation file inside each project's `.claude/` directory. Product output. |
  | `crons/notify-failure.sh` | `$logfile` | Function parameter. Actual runtime path is always an approved `$CLAUDE_LOG_DIR/<name>.log` passed by the caller. The regex can't trace params across function scopes. |

  **Why these slip through.** OBS001 is pure prefix-matching on redirect
  targets. It can't read variable intent (`NOTE_PATH` looks identical to
  `LOGFILE`), can't follow function parameters across call scopes, and
  can't distinguish product outputs from operational logs. See the
  "Future improvements" section below for the planned heuristic upgrades.

- **OBS002** `claude` call without timestamps → pipe through `ts` or prepend
  `date -u +%FT%TZ`.
- **OBS003** cron not sourcing `notify-failure.sh` → source it and call
  `notify_failure` from `trap ... ERR`.
- **OBS004** no `duration_ms=` / `status=` markers → emit them on completion.
- **OBS005** no log rotation script found → add one (`find -mtime +30 -delete`
  on the log directory).
- **OBS006** hook command doesn't resolve → fix the path in `settings.json`
  or create the missing script.

### Documentation (DOC*)

- **DOC001** script header missing fields → add the 4-line header
  (purpose/inputs/outputs/side-effects).
- **DOC002** env var has no preceding comment → add a `# purpose: ...`
  line above each export.
- **DOC003** `claude/README.md` missing → create it.
- **DOC004** no ADRs → capture decisions in
  `docs/superpowers/adr/YYYY-MM-DD-<topic>.md`.
- **DOC005** cron has no runbook → create
  `docs/superpowers/runbooks/<stem>.md`.
- **DOC006** crontab entry has no comment → add a `# purpose:` line above it.
- **DOC007** no `settings.hooks.md` → create it, document each wired event.

### Cross-cutting (CROSS*)

- **CROSS001** symlink broken → `ln -sf <target> <link>` using the fix_hint.
- **CROSS002** broad bash permission pattern → narrow to specific commands.
- **CROSS003** leaked secret → **rotate the credential immediately**, then
  remove it from tracked files and move to env vars or a secret manager.
- **CROSS004** uncommitted change (Info) → commit or stash it.

---

## Score interpretation

Score is `max(0, 1000 - Σ(severity_weight × count))`. Weights: Critical=10,
High=5, Medium=2, Low=1, Info=0.

- **≥ 900**: Excellent.
- **700–899**: Solid baseline, some gaps.
- **500–699**: Significant gaps; pick a phase plan and execute.
- **< 500**: Multiple systemic issues; treat as phase-2+ of a larger
  hardening project.

Track score trend via `git log --oneline -- docs/superpowers/audits/`. A
drop between runs is a regression — diff the report to see what flipped.

---

## Future improvements

Planned but unscheduled heuristic upgrades that would eliminate the OBS001
false positives listed above. Tracked here so a future session can pick
them up as its own brainstorm → spec → plan → execute cycle:

1. **Variable-name signals.** Skip writes whose target variable matches
   `/NOTE|DOC|BREADCRUMB|VAULT|REPORT/i`. The variable name is the cheapest
   intent signal available and catches 3 of the 4 current false positives.
2. **Extension skip.** Skip writes whose resolved path ends in `.md`,
   `.html`, or `.json` — document/data extensions, not log formats.
3. **Product-root allowlist.** Skip writes whose resolved path starts with
   `$OBSIDIAN_VAULT` or any path declared in a new `[tool.cstack-audit]`
   config section in `pyproject.toml` / `.cstack-audit.toml`.
4. **Inline suppression.** Honour an `# audit-ignore: OBS001` comment on
   or immediately above the write line. Rationale captured inline so
   `grep -rn 'audit-ignore'` turns up every active suppression.

None of these should change the set of _real_ OBS001 findings. The
pre-fix baseline (`2026-04-18`) had 7 such findings and all were in
operational log paths that got correctly routed to `$CLAUDE_LOG_DIR`
in the fix round. The upgrades only filter out product-output writes
that share the `$VAR/path` syntax pattern — a distinct class of write
the current heuristic can't disambiguate.

---

## Design principles

Rules of thumb that have emerged from the audit tool's own incident
history and should guide any future hardening work on the Claude stack
(hooks, crons, audit checks, subagent reports):

1. **Transcript-visible verification beats unseen checks.** Reports must
   paste literal gate output, not summaries. A claim of "gates passed"
   without the pasted command output is unverifiable and therefore
   untrustworthy. See
   `docs/superpowers/adr/2026-04-20-subagent-self-verification.md`.
2. **Gates should be tamper-evident.** A gate that can silently exit
   under `set -e` (PR #111) or be bypassed by a stale cache is worse
   than no gate — it creates false confidence. Use EXIT traps, not
   silent exits. Capture exit codes explicitly. See
   `docs/superpowers/adr/2026-04-20-pre-pr-gate-consistency.md`.
3. **Silent code mutation is a bug.** Tooling that rewrites user code
   (e.g. `ruff check --fix` inside `claude/hooks/auto-format.sh`) must
   surface what it changed as an actionable warning. Discarding
   diagnostics via `2>/dev/null` is a silent-mutation vector. Capture
   output, filter for `F401`/`F403`-class fixes, and emit warnings.
4. **Snapshots should be git-tracked, not ephemeral.** Audit reports
   live under `docs/superpowers/audits/` and are committed. Score
   trend is recoverable from `git log`. Ephemeral snapshots in
   `$TMPDIR` or unversioned paths make regressions invisible.
5. **If a reader can't reproduce what happened from the artifact, the
   artifact isn't enough.** This is the unifying constraint behind the
   four rules above. Artifacts (PR bodies, audit reports, subagent
   reports, hook logs) must be self-contained evidence — not pointers
   to state that may have already changed.

These principles apply to every layer of the stack the audit tool
inventories. They are the "why" behind the specific check IDs above.

---

## Related

- Tool source: `~/.dotfiles/claude-stack-audit/`
- ADR (why Python): `docs/superpowers/adr/2026-04-18-python-audit-tool.md`
- ADR (pre-PR gate bypass): `docs/superpowers/adr/2026-04-20-pre-pr-gate-consistency.md`
- ADR (subagent self-verification): `docs/superpowers/adr/2026-04-20-subagent-self-verification.md`
- Spec: `docs/superpowers/specs/2026-04-17-claude-stack-audit-tool-design.md`
- Phase plans: `docs/superpowers/plans/2026-04-*-claude-stack-audit-*.md`
