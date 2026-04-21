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

  **Product-output writes are filtered automatically.** The check skips
  writes whose target variable name matches `NOTE`/`BREADCRUMB`/`DOC`/
  `VAULT_NOTE` (case-insensitive), whose resolved path ends in
  `.md`/`.html`/`.htm`, or whose path is rooted in `$OBSIDIAN_VAULT` or
  iCloud Drive. Naming a product-output variable `LOGFILE` will still
  flag — rename it, or use the escape hatch.

  **Escape hatch** — for writes where static analysis can't determine
  intent (e.g. a function parameter resolved only at runtime), add an
  inline suppression on the redirect line or up to 3 lines above it:

  ```bash
  # audit-ignore: OBS001 — $logfile is the caller's approved path
  echo "status=ok" >> "$logfile"
  ```

  Multiple IDs are allowed (`# audit-ignore: OBS001, OBS002`). A reason
  is convention, not parser-enforced; always write one so
  `grep -rn 'audit-ignore'` turns up why every suppression exists.
  Syntax and ruleset pinned by
  `docs/superpowers/specs/2026-04-21-obs001-heuristic-upgrade.md`.

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

Unscheduled hardening tracked here so a future session can pick each up
as its own brainstorm → spec → plan → execute cycle:

1. **`${VAR:-default}` resolver.** `_resolve_path_vars` in
   `checks/observability.py` walks plain `$VAR` / `${VAR}` prefixes but
   does not expand the bash default-value operator. `$DRIFT_LOG` in
   `hooks/auto-format.sh` defaults to `$HOME/.claude/logs/...` — an
   approved path — but the unresolved RHS leaves OBS001 flagging it.
2. **Config-driven product-root allowlist.** Rules 1–3 of the current
   OBS001 heuristic cover Obsidian/iCloud explicitly. A
   `[tool.cstack-audit]` section in `pyproject.toml` /
   `.cstack-audit.toml` would let projects declare their own
   product-output roots without a code change.

(Rules 1, 2, and 4 from the earlier version of this list — variable-name
signals, extension skip, inline suppression — shipped 2026-04-21. See
`docs/superpowers/specs/2026-04-21-obs001-heuristic-upgrade.md`.)

---

## Hooks behaviour

Observed behaviour of `claude/hooks/safety-guards.sh` — a PreToolUse
hook that pattern-matches every Bash command Claude runs and blocks
destructive operations via exit 2. Documented here so future sessions
can distinguish working-as-intended blocks from actual bugs before
weakening the guard.

### Known good: blocks destructive commands

The hook correctly blocks:

- `git reset --hard` (any ref).
- `git push --force` / `-f` without `--force-with-lease`.
- `git push origin main|master` — direct push to the default branch.
- `rm -rf` targeting critical paths (`/`, `~/`, `$HOME`, `/usr`,
  `/etc`, `/var`, `/opt`, `/bin`, `/sbin`, `/lib`, `..`, `*`) —
  case-insensitive variants for macOS's case-insensitive filesystem.
- `curl ... | bash|sh|zsh` pipe-to-shell patterns.
- `chmod 777`, fork bombs, destructive SQL (`DROP TABLE`, `TRUNCATE`,
  unguarded `DELETE FROM`), Alembic downgrades against `prod`, and
  direct production DB connections (`psql`/`mysql`/`mongo`/`redis-cli`
  with `prod`/`production` in the target).

**Concrete incident — PR #107/#108 merge-cleanup session.** An agent
attempting to align local `main` with `origin/main` after a messy
add/add merge issued `git reset --hard origin/main`. The hook fired
(`BLOCKED: git reset --hard destroys uncommitted work. Use git stash
instead.`) and returned exit 2. The agent's working tree held
uncommitted in-progress work at the time; a silent `--hard` would
have overwritten it. Correct outcome.

**Treat as working as intended.** If a future session finds the guard
annoying and wants to weaken it, pause — the canonical reason it
exists is that it caught a real destructive-command attempt during an
agent session. The fix for any single firing is almost always "use
the non-destructive alternative the error message recommends" (`git
stash`, `--force-with-lease`, feature branch + PR) rather than
relaxing the pattern.

### Known false positive: literal-string matching in prose

The matcher substring-matches command strings regardless of token
position (e.g. line 58 of `safety-guards.sh` is
`[[ "$COMMAND" =~ git[[:space:]]+reset[[:space:]]+--hard ]]`). That
means it fires on strings like `git reset --hard` or `rm -rf /` when
they appear as *argument* content to a non-destructive command —
most commonly PR body text passed to `gh pr create --body "..."`, or
heredoc-composed PR bodies whose fenced code blocks illustrate
destructive commands.

Not a critical issue — the hook stays fail-closed, so false positives
cost an iteration but never silently let a real destructive command
through. **Workaround:** write the body to a file
(`cat > /tmp/pr-body.md <<'EOF' ... EOF`) and call
`gh pr create --body-file /tmp/pr-body.md`; the substring then lives
in file content the hook never inspects.

**Suggested future fix** (not in scope for this runbook entry): scope
matching to actual command position — tokenize the command string on
shell delimiters (`;`, `&&`, `||`, `|`) and match only on the first
word of each statement, rather than substring-matching the full line.
Kills the prose false positive without narrowing the guard's
blast radius for real destructive commands. Tracked here; a future
session can pick it up as its own brainstorm → spec → plan → execute
cycle.

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
